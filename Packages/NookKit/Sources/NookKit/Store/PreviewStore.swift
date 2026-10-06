#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

/// In-memory stores for previews and UI tests (04 §11). `small` is four rooms with spots and
/// containers; `lived` adds a dozen items with photos; `items1k` is 1,000 items for the grid
/// scrolling budget (PRD §9).
@MainActor
public enum PreviewStore {
    public enum Size: String, Sendable {
        case empty, small, many, lived, items1k
    }

    public static func seeded(_ size: Size) -> ModelContainer {
        do {
            let container = try NookStore.makeContainer(inMemory: true)
            switch size {
            case .empty: break
            case .small: try seedSmall(container.mainContext)
            case .many: try seedMany(container.mainContext)
            case .lived:
                try seedSmall(container.mainContext)
                try seedItems(container.mainContext)
            case .items1k: try seedThousand(container.mainContext)
            }
            return container
        } catch {
            fatalError("Preview store failed: \(error)")   // debug builds only
        }
    }

    private static func seedSmall(_ context: ModelContext) throws {
        let rooms = RoomService(context: context)
        let kitchen = try rooms.addRoom(named: "Kitchen")
        for spot in ["Counter", "Pantry", "Top drawer"] { try rooms.addSpot(named: spot, in: kitchen) }
        let living = try rooms.addRoom(named: "Living room")
        try rooms.addSpot(named: "Bookshelf", in: living)
        try rooms.addContainer(named: "Blue bin", in: living)
        let bedroom = try rooms.addRoom(named: "Bedroom")
        let wardrobe = try rooms.addSpot(named: "Wardrobe", in: bedroom)
        try rooms.addContainer(named: "Shoe box", in: bedroom, inside: wardrobe)
        let garage = try rooms.addRoom(named: "Garage")
        let shelf = try rooms.addSpot(named: "Metal shelf", in: garage)
        try rooms.addContainer(named: "Box 14", in: garage, inside: shelf)
        try context.save()
    }

    private static func seedItems(_ context: ModelContext) throws {
        let rooms = try RoomService(context: context).rooms()
        let byName = Dictionary(uniqueKeysWithValues: rooms.map { ($0.name, $0) })
        func spot(_ room: String, _ name: String) -> Location? {
            guard let room = byName[room] else { return nil }
            let all = (room.spots ?? [])
            return Location(room: room, spot: all.first { $0.name == name })
        }
        let entries: [(String, String, Decimal?, Location?, Bool)] = [
            ("Espresso machine", "Appliances", 649, spot("Kitchen", "Counter"), false),
            ("Stand mixer", "Appliances", 429, spot("Kitchen", "Counter"), false),
            ("Cast iron skillet", "Kitchen", 45, spot("Kitchen", "Top drawer"), false),
            ("Olive oil", "Kitchen", nil, spot("Kitchen", "Pantry"), false),
            ("Record player", "Electronics", 299, spot("Living room", "Bookshelf"), false),
            ("Board games", "Kids & Baby", 60, spot("Living room", "Blue bin"), false),
            ("Passport", "Documents", nil, spot("Bedroom", "Wardrobe"), true),
            ("Grandma’s ring", "Jewelry", 1_800, spot("Bedroom", "Shoe box"), true),
            ("Winter coat", "Clothing", 240, spot("Bedroom", "Wardrobe"), false),
            ("Cordless drill", "Tools", 159, spot("Garage", "Metal shelf"), false),
            ("Camping tent", "Sports", 320, spot("Garage", "Box 14"), false),
            ("Bike pump", "Sports", 35, byName["Garage"].map { Location(room: $0) }, false),
        ]
        let items = ItemService(context: context)
        for (index, entry) in entries.enumerated() {
            var draft = ItemDraft(currencyCode: Locale.current.currency?.identifier ?? "USD", location: entry.3)
            (draft.name, draft.category, draft.price, draft.isPrivate) = (entry.0, entry.1, entry.2, entry.4)
            if let saved = try? BlobStore.shared.savePhoto(swatch(index)) {
                draft.photos = [.init(fileName: saved.fileName, width: saved.width, height: saved.height)]
            }
            try items.create(draft)
        }
        try context.save()
    }

    private static func seedThousand(_ context: ModelContext) throws {
        let rooms = RoomService(context: context)
        let room = try rooms.addRoom(named: "Storage")
        let photos = (0..<20).compactMap { try? BlobStore.shared.savePhoto(swatch($0)) }
        for number in 1...1_000 {
            let item = Item(name: "Thing \(number)")
            context.insert(item)
            item.room = room
            item.price = Decimal(number)
            item.currencyCode = "USD"
            if !photos.isEmpty {
                let saved = photos[number % photos.count]
                let photo = Photo(fileName: saved.fileName)   // shared files; fine for a test seed
                (photo.width, photo.height) = (saved.width, saved.height)
                context.insert(photo)
                photo.item = item
            }
        }
        try context.save()
    }

    /// A warm two-tone photo stand-in, different for each index.
    private static func swatch(_ index: Int) -> Data {
        let hues: [(CGFloat, CGFloat, CGFloat)] = [(0.85, 0.62, 0.45), (0.55, 0.68, 0.55), (0.52, 0.64, 0.78),
                                                  (0.72, 0.60, 0.78), (0.90, 0.80, 0.50), (0.80, 0.55, 0.60)]
        let (r, g, b) = hues[index % hues.count]
        let context = CGContext(data: nil, width: 400, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        context.setFillColor(CGColor(red: r * 0.8, green: g * 0.8, blue: b * 0.8, alpha: 1))
        context.fillEllipse(in: CGRect(x: 80 + index % 5 * 10, y: 120, width: 240, height: 240))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func seedMany(_ context: ModelContext) throws {
        let rooms = RoomService(context: context)
        for number in 1...54 { try rooms.addRoom(named: "Room \(number)") }
        let long = try rooms.addRoom(named: "The spare bedroom at the very end of the upstairs hallway")
        try rooms.addSpot(named: "The tall wardrobe with the sliding mirror doors on the left", in: long)
        try context.save()
    }
}
#endif
