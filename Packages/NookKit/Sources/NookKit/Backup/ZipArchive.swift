import Foundation
import Compression
import zlib

/// The zip inside a `.nookbackup` (D12). The iOS 27 SDK has no zip API to read one (D56),
/// and Nook takes no dependencies, so this is the smallest reader and writer that does.
///
/// The writer stores entries uncompressed (photos are already HEIC) and switches to zip64
/// past 4 GB. The reader takes stored and deflated entries, so a backup someone unzipped and
/// zipped again on a Mac still opens.
// ponytail: no encryption, no multi-disk, no data descriptors; entries are read whole, so
// one file must fit in memory (Nook's largest is a receipt PDF).
public enum ZipArchive {
    public enum Failure: Error, Equatable {
        case notAZip
        case unsupported
        case corrupt
        case unsafePath
    }

    // MARK: Writing

    public final class Writer {
        private struct Entry {
            let name: Data
            let crc: UInt32
            let size: UInt64
            let offset: UInt64
        }

        private let handle: FileHandle
        private var entries: [Entry] = []
        private var offset: UInt64 = 0

        public init(url: URL) throws {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            handle = try FileHandle(forWritingTo: url)
        }

        public func add(_ path: String, data: Data) throws {
            let name = Data(path.utf8)
            let crc = ZipArchive.crc(data)
            let size = UInt64(data.count)
            var header = Data()
            header.le(UInt32(0x0403_4b50))
            header.le(UInt16(45))             // version needed: zip64-capable
            header.le(UInt16(0x0800))         // UTF-8 names
            header.le(UInt16(0))              // stored
            header.le(UInt16(0)); header.le(UInt16(0x21))   // 1980-01-01 00:00; dates aren't used
            header.le(crc)
            header.le(UInt32(size)); header.le(UInt32(size))   // one file is never 4 GB
            header.le(UInt16(name.count)); header.le(UInt16(0))
            header.append(name)
            try handle.write(contentsOf: header)
            try handle.write(contentsOf: data)
            entries.append(Entry(name: name, crc: crc, size: size, offset: offset))
            offset += UInt64(header.count) + size
        }

        public func add(_ path: String, file: URL) throws {
            try add(path, data: Data(contentsOf: file, options: .mappedIfSafe))
        }

        public func finish() throws {
            let directoryOffset = offset
            var directory = Data()
            for entry in entries {
                let big = entry.offset >= 0xFFFF_FFFF
                directory.le(UInt32(0x0201_4b50))
                directory.le(UInt16(45)); directory.le(UInt16(45))
                directory.le(UInt16(0x0800)); directory.le(UInt16(0))
                directory.le(UInt16(0)); directory.le(UInt16(0x21))
                directory.le(entry.crc)
                directory.le(UInt32(entry.size)); directory.le(UInt32(entry.size))
                directory.le(UInt16(entry.name.count)); directory.le(UInt16(big ? 12 : 0)); directory.le(UInt16(0))
                directory.le(UInt16(0)); directory.le(UInt16(0)); directory.le(UInt32(0))
                directory.le(big ? UInt32(0xFFFF_FFFF) : UInt32(entry.offset))
                directory.append(entry.name)
                if big {   // zip64 extra field: just the offset
                    directory.le(UInt16(0x0001)); directory.le(UInt16(8)); directory.le(entry.offset)
                }
            }
            try handle.write(contentsOf: directory)
            let directorySize = UInt64(directory.count)
            let zip64 = directoryOffset >= 0xFFFF_FFFF || entries.count >= 0xFFFF
            var end = Data()
            if zip64 {
                let recordOffset = directoryOffset + directorySize
                end.le(UInt32(0x0606_4b50)); end.le(UInt64(44))
                end.le(UInt16(45)); end.le(UInt16(45)); end.le(UInt32(0)); end.le(UInt32(0))
                end.le(UInt64(entries.count)); end.le(UInt64(entries.count))
                end.le(directorySize); end.le(directoryOffset)
                end.le(UInt32(0x0706_4b50)); end.le(UInt32(0)); end.le(recordOffset); end.le(UInt32(1))
            }
            end.le(UInt32(0x0605_4b50)); end.le(UInt16(0)); end.le(UInt16(0))
            end.le(UInt16(min(entries.count, 0xFFFF))); end.le(UInt16(min(entries.count, 0xFFFF)))
            end.le(UInt32(min(directorySize, 0xFFFF_FFFF)))
            end.le(zip64 ? UInt32(0xFFFF_FFFF) : UInt32(directoryOffset))
            end.le(UInt16(0))
            try handle.write(contentsOf: end)
            try handle.close()
        }
    }

    // MARK: Reading

    public struct Entry: Sendable {
        public let path: String
        let method: UInt16
        let crc: UInt32
        let compressedSize: UInt64
        let size: UInt64
        let offset: UInt64
    }

    public final class Reader {
        public let entries: [Entry]
        private let handle: FileHandle

        public init(url: URL) throws {
            handle = try FileHandle(forReadingFrom: url)
            entries = try Self.directory(handle)
        }

        deinit { try? handle.close() }

        public func entry(_ path: String) -> Entry? { entries.first { $0.path == path } }

        public func data(_ entry: Entry) throws -> Data {
            try handle.seek(toOffset: entry.offset)
            let local = try read(30)
            guard local.u32(0) == 0x0403_4b50 else { throw Failure.corrupt }
            try handle.seek(toOffset: entry.offset + 30 + UInt64(local.u16(26)) + UInt64(local.u16(28)))
            let stored = try read(Int(entry.compressedSize))
            let data: Data
            switch entry.method {
            case 0: data = stored
            case 8: data = try ZipArchive.inflate(stored, size: Int(entry.size))
            default: throw Failure.unsupported
            }
            guard ZipArchive.crc(data) == entry.crc else { throw Failure.corrupt }
            return data
        }

        private func read(_ count: Int) throws -> Data {
            guard count > 0 else { return Data() }
            guard let data = try handle.read(upToCount: count), data.count == count else { throw Failure.corrupt }
            return data
        }

        private static func directory(_ handle: FileHandle) throws -> [Entry] {
            let length = try handle.seekToEnd()
            let tail = min(length, 22 + 0xFFFF)
            try handle.seek(toOffset: length - tail)
            guard let end = try handle.read(upToCount: Int(tail)),
                  let eocd = stride(from: end.count - 22, through: 0, by: -1).first(where: { end.u32($0) == 0x0605_4b50 })
            else { throw Failure.notAZip }
            var count = UInt64(end.u16(eocd + 10))
            var start = UInt64(end.u32(eocd + 16))
            if count == 0xFFFF || start == 0xFFFF_FFFF, eocd >= 20, end.u32(eocd - 20) == 0x0706_4b50 {
                try handle.seek(toOffset: end.u64(eocd - 12))
                guard let record = try handle.read(upToCount: 56), record.count == 56, record.u32(0) == 0x0606_4b50
                else { throw Failure.corrupt }
                (count, start) = (record.u64(32), record.u64(48))
            }
            guard start < length else { throw Failure.corrupt }
            try handle.seek(toOffset: start)
            guard let directory = try handle.read(upToCount: Int(length - start)) else { throw Failure.corrupt }
            var entries: [Entry] = []
            var at = 0
            for _ in 0..<count {
                guard at + 46 <= directory.count, directory.u32(at) == 0x0201_4b50 else { throw Failure.corrupt }
                let nameLength = Int(directory.u16(at + 28)), extraLength = Int(directory.u16(at + 30))
                let commentLength = Int(directory.u16(at + 32))
                guard at + 46 + nameLength + extraLength <= directory.count else { throw Failure.corrupt }
                var compressed = UInt64(directory.u32(at + 20)), size = UInt64(directory.u32(at + 24))
                var offset = UInt64(directory.u32(at + 42))
                var extra = at + 46 + nameLength
                while extra + 4 <= at + 46 + nameLength + extraLength {   // zip64 sizes and offset
                    let id = directory.u16(extra), fieldLength = Int(directory.u16(extra + 2))
                    if id == 0x0001 {
                        var field = extra + 4
                        if size == 0xFFFF_FFFF { size = directory.u64(field); field += 8 }
                        if compressed == 0xFFFF_FFFF { compressed = directory.u64(field); field += 8 }
                        if offset == 0xFFFF_FFFF { offset = directory.u64(field) }
                    }
                    extra += 4 + fieldLength
                }
                let nameStart: Int = directory.startIndex + at + 46
                let path = String(decoding: directory[nameStart..<(nameStart + nameLength)], as: UTF8.self)
                entries.append(Entry(path: path, method: directory.u16(at + 10), crc: directory.u32(at + 16),
                                     compressedSize: compressed, size: size, offset: offset))
                at += 46 + nameLength + extraLength + commentLength
            }
            return entries
        }
    }

    /// An entry's path inside `folder`, refusing anything that would land outside it: the
    /// file comes from outside the app.
    public static func safeURL(for path: String, in folder: URL) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !path.contains("\\"), !parts.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
        else { throw Failure.unsafePath }
        return folder.appending(path: path)
    }

    static func crc(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { UInt32(zlib.crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt($0.count))) }
    }

    static func inflate(_ data: Data, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        guard !data.isEmpty else { throw Failure.corrupt }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in
                compression_decode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, size,
                                          input.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Failure.corrupt }
        return output
    }
}

private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    func u16(_ at: Int) -> UInt16 { int(at) }
    func u32(_ at: Int) -> UInt32 { int(at) }
    func u64(_ at: Int) -> UInt64 { int(at) }

    private func int<T: FixedWidthInteger>(_ at: Int) -> T {
        var value: T = 0
        for byte in 0..<MemoryLayout<T>.size { value |= T(self[startIndex + at + byte]) << (8 * byte) }
        return value
    }
}
