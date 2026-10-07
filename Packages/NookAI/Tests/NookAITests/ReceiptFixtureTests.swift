import Foundation
import Testing
@testable import NookAI

// OCR then parse every fixture in Fixtures/receipts against its JSON (05 §1, D48). Clean
// receipts must all read right; the hard set (rotated, faded, noisy) and real photos need 80%.

private let fixtures = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appending(path: "Fixtures")

private struct Expected: Decodable {
    let total: String
    let date: String
}

private struct Outcome {
    let name: String
    let totalRight: Bool
    let dateRight: Bool
    let read: String
}

private func readAll(_ folder: String) async throws -> [Outcome] {
    let directory = fixtures.appending(path: "receipts/\(folder)")
    let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    var outcomes: [Outcome] = []
    for json in files where json.pathExtension == "json" {
        let expected = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: json))
        let base = json.deletingPathExtension()
        let document: DocumentInput? = files.contains(base.appendingPathExtension("pdf"))
            ? DocumentInput(pdf: base.appendingPathExtension("pdf"))
            : files.first { $0.deletingPathExtension() == base && $0.pathExtension != "json" }
                .flatMap { try? Data(contentsOf: $0) }.flatMap(DocumentInput.init(imageData:))
        let reading = try await NookAI.classic.readReceipt(try #require(document, "\(base.lastPathComponent)"))
        let date = reading.dates.first.map { Calendar.current.dateComponents([.year, .month, .day], from: $0.value) }
        let parts = expected.date.split(separator: "-").compactMap { Int($0) }
        outcomes.append(Outcome(
            name: base.lastPathComponent,
            totalRight: reading.amounts.first?.value == Decimal(string: expected.total),
            dateRight: date.map { [$0.year!, $0.month!, $0.day!] } == parts,
            read: "\(reading.amounts.first?.text ?? "–") \(reading.dates.first?.text ?? "–")"))
    }
    return outcomes
}

@Test func cleanReceiptsAllReadRight() async throws {
    let outcomes = try await readAll("clean")
    #expect(outcomes.count >= 12)
    for outcome in outcomes {
        #expect(outcome.totalRight && outcome.dateRight, "\(outcome.name) read \(outcome.read)")
    }
}

@Test(arguments: ["hard", "real"])
func damagedReceiptsMostlyReadRight(folder: String) async throws {
    let outcomes = try await readAll(folder)
    guard !outcomes.isEmpty else { return }   // real/ fills up later
    let totals = Double(outcomes.filter(\.totalRight).count) / Double(outcomes.count)
    let dates = Double(outcomes.filter(\.dateRight).count) / Double(outcomes.count)
    let misses = outcomes.filter { !$0.totalRight || !$0.dateRight }.map { "\($0.name): \($0.read)" }
    #expect(totals >= 0.8 && dates >= 0.8, "totals \(totals), dates \(dates); misses \(misses)")
}

@Test func stickerFixtureReadsSerialAndModel() async throws {
    let data = try Data(contentsOf: fixtures.appending(path: "serials/brewmaster.jpg"))
    let reading = try await NookAI.classic.readSerial(from: try #require(PhotoInput(data: data)))
    #expect(reading.serial == "7XK2-48812-QA")
    #expect(reading.model == "EM-4200")
}
