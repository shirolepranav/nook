import SwiftUI
import SwiftData
import NookKit
import NookUI

/// The 500 common household items, for name autocomplete (PRD §5) and their categories.
enum CommonItems {
    static let all = CommonItem.load(from: Bundle.main.url(forResource: "common-items", withExtension: "json"))
    static let categories: [String] = {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }()
}

/// The currency new items start in and Home totals use (D41): the region's, until Settings
/// has a picker.
enum HomeCurrency {
    static var code: String { Locale.current.currency?.identifier ?? "USD" }
}

/// Item actions shared by the grid, detail, selection and Recently Deleted, each with the
/// toast it shows (D14: every delete gets Undo).
@MainActor
struct ItemActions {
    let context: ModelContext
    let undoManager: UndoManager?

    var service: ItemService { ItemService(context: context) }

    func delete(_ items: [Item]) -> ToastMessage {
        service.delete(items)
        try? context.save()
        let text: LocalizedStringResource = items.count == 1
            ? "Deleted \(items[0].name). You can restore it for 30 days."
            : "Deleted \(items.count) items. You can restore them for 30 days."
        return ToastMessage(symbol: "trash", text, undo: undo)
    }

    func setPrivate(_ items: [Item], _ isPrivate: Bool) -> ToastMessage {
        service.setPrivate(items, isPrivate)
        try? context.save()
        return ToastMessage(symbol: isPrivate ? "lock.fill" : "lock.open",
                            isPrivate ? "Marked Private." : "No longer Private.", undo: undo)
    }

    func duplicate(_ item: Item) -> ToastMessage {
        do {
            try service.duplicate(item)
            try context.save()
            return ToastMessage(symbol: "plus.square.on.square", "Duplicated \(item.name).", undo: undo)
        } catch {
            return ToastMessage(symbol: "exclamationmark.circle", "Couldn’t duplicate it. Your items are safe.")
        }
    }

    /// F6: moves through `LocationService` (the only writer), as one Undo step named "Move".
    /// `nil` when nothing actually moved.
    func move(_ items: [Item], to location: Location, source: LocationEvent.Source = .manual) -> ToastMessage? {
        let moved = LocationService(context: context).move(items, to: location, source: source)
        guard !moved.isEmpty else { return nil }
        undoManager?.setActionName(String(localized: "Move"))
        try? context.save()
        let text: LocalizedStringResource = switch (source, moved.count) {
        case (.found, _): "Found in \(location.path)."
        case (_, 1): "Moved to \(location.path)."
        default: "Moved \(moved.count) items to \(location.path)."
        }
        return ToastMessage(symbol: "arrow.up.and.down.and.arrow.left.and.right", text, undo: undo)
    }

    // MARK: Lending and warranties (F4, F7)

    func lend(_ item: Item, to person: String, contactID: String?, lentAt: Date, dueAt: Date?, remind: Bool) throws -> ToastMessage {
        let wasOut = item.activeLoan != nil
        let loan = try service.lend(item, to: person, contactID: contactID, lentAt: lentAt, dueAt: dueAt, remind: remind)
        try context.save()
        return ToastMessage(symbol: "person.fill", wasOut ? "Saved." : "Lent to \(loan.personName).", undo: undo)
    }

    func markReturned(_ loan: Loan) -> ToastMessage {
        service.markReturned(loan)
        try? context.save()
        let name = loan.item?.name ?? ""
        return ToastMessage(symbol: "checkmark", "\(name) is back.", undo: undo)
    }

    func setReminders(_ warranty: Warranty, on: Bool) -> ToastMessage {
        warranty.remindersOn = on
        try? context.save()
        return ToastMessage(symbol: on ? "bell" : "bell.slash", on ? "Reminders on." : "Reminders off.", undo: undo)
    }

    func restore(_ items: [Item]) -> ToastMessage {
        service.restore(items)
        try? context.save()
        if items.count == 1, let room = items[0].room?.name {
            return ToastMessage(symbol: "arrow.uturn.backward", "Restored to \(room).", undo: undo)
        }
        return ToastMessage(symbol: "arrow.uturn.backward", "Restored.", undo: undo)
    }

    private func undo() {
        undoManager?.undo()
        try? context.save()
    }
}

extension Item {
    /// "Kitchen → Counter", or "No room yet".
    var placeText: Text {
        Location(of: self).map { Text(verbatim: $0.path) } ?? Text("No room yet")
    }

    var badges: [CardBadge.Kind] {
        // The boards show no warranty badge on cards; Home and R-04 carry that (D50).
        (isPrivate ? [.privateItem] : []) + (activeLoan == nil ? [] : [.lent])
    }

    var value: (amount: Decimal, currencyCode: String)? {
        price.map { ($0, currencyCode.isEmpty ? HomeCurrency.code : currencyCode) }
    }
}

/// Loads a stored photo's thumbnail (or a downsampled full image) and hands it to `content`,
/// `nil` until it's ready (03 §8.9: the placeholder stands in).
struct StoredImage<Content: View>: View {
    let fileName: String?
    var folder: BlobStore.Folder = .photos
    var maxPixels: Int?
    @ViewBuilder let content: (Image?) -> Content
    @State private var image: Image?

    var body: some View {
        content(image)
            .task(id: fileName) {
                guard let fileName else { image = nil; return }
                let blobs = BlobStore.shared
                let cgImage = if let maxPixels {
                    await blobs.image(fileName, in: folder, maxPixels: maxPixels)
                } else {
                    await blobs.thumbnail(fileName)
                }
                image = cgImage.map { Image(decorative: $0, scale: 1) }
            }
    }
}

// MARK: Navigation

extension EnvironmentValues {
    /// Shared by item cards and the item screen for the zoom transition (03 §9).
    @Entry var itemZoom: Namespace.ID?
}

extension View {
    /// Put inside each NavigationStack root: items open their detail with a zoom from the card,
    /// and rooms and spots open from anywhere in the stack (Home, a sidebar room, Find's
    /// answers). One registration per type, at the root, so pushed screens never repeat it.
    func itemNavigation() -> some View {
        modifier(ItemNavigation())
    }

    /// The card side of the zoom transition.
    func itemZoomSource(_ item: Item) -> some View {
        modifier(ItemZoomSource(id: item.id))
    }
}

private struct ItemNavigation: ViewModifier {
    @Namespace private var zoom

    func body(content: Content) -> some View {
        content
            .environment(\.itemZoom, zoom)
            .navigationDestination(for: Item.self) { item in
                ItemDetailScreen(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: zoom))   // cross-fades under Reduce Motion
            }
            .navigationDestination(for: Room.self) { RoomScreen(room: $0) }
            .navigationDestination(for: Spot.self) { SpotScreen(spot: $0) }
            .navigationDestination(for: ReportsRoute.self) { route in   // R-04, R-05 (P7)
                switch route {
                case .warranties: WarrantiesScreen()
                case .lentOut: LentOutScreen()
                }
            }
    }
}

private struct ItemZoomSource: ViewModifier {
    let id: UUID
    @Environment(\.itemZoom) private var zoom

    func body(content: Content) -> some View {
        if let zoom {
            content.matchedTransitionSource(id: id, in: zoom)
        } else {
            content
        }
    }
}
