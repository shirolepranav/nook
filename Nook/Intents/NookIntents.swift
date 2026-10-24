import AppIntents
import SwiftData
import NookKit

/// "Where is my passport?" (PRD §6, 04 §8). The answer comes from the item's records only,
/// as Find's answer card does (CLAUDE.md: AI never invents).
struct FindItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Item"
    static let description = IntentDescription("Says where something is, from what you’ve saved in Nook & Cranny.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Item") var item: ItemEntity

    init() {}
    init(item: ItemEntity) { self.item = item }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let found = try ItemQuery().items([item.id]).first else { throw IntentError.notFound }
        let answer = Self.answer(for: found)
        return .result(value: answer, dialog: "\(answer)")
    }

    /// "Passport is in Office → Desk. Last confirmed Aug 3." Lent and packed come first, as
    /// on the answer card (F-03).
    @MainActor
    static func answer(for item: Item) -> String {
        let confirmed = item.lastConfirmedAt.formatted(.dateTime.month(.abbreviated).day())
        if let loan = item.activeLoan {
            return String(localized: "\(loan.personName) has your \(item.name).")
        }
        guard let place = Location(of: item) else {
            return String(localized: "\(item.name) doesn’t have a place yet.")
        }
        if let box = place.spot, box.isContainer, let packedAt = box.packedAt {
            let packed = packedAt.formatted(.dateTime.month(.abbreviated).day())
            return String(localized: "\(item.name) is in \(place.path), packed \(packed).")
        }
        return String(localized: "\(item.name) is in \(place.path). Last confirmed \(confirmed).")
    }
}

/// "I put the passport in the safe" from Siri or Shortcuts (PRD §6, F6). Nothing moves until
/// the user confirms; then it goes through `LocationService` like every move (CLAUDE.md).
struct MoveItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Item"
    static let description = IntentDescription("Moves something to another room, spot or box, after you confirm.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Item") var item: ItemEntity
    @Parameter(title: "To") var place: PlaceEntity

    init() {}
    init(item: ItemEntity, place: PlaceEntity) { (self.item, self.place) = (item, place) }

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$item) to \(\.$place)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try IntentStore.context
        guard let found = try ItemQuery().items([item.id]).first,
              let location = PlaceQuery.location(place.id, in: context) else { throw IntentError.notFound }
        if Location(of: found) == location {
            return .result(dialog: "\(found.name) is already in \(location.path).")
        }
        try await requestConfirmation(actionName: .continue, dialog: "Move \(found.name) to \(location.path)?")
        try Self.move(found, to: location, in: context)
        return .result(dialog: "Moved \(found.name) to \(location.path).")
    }

    /// The write itself, after the confirmation.
    @MainActor
    static func move(_ item: Item, to location: Location, in context: ModelContext) throws {
        _ = LocationService(context: context).move([item], to: location, source: .siri)
        try context.save()
    }
}

/// "What's in the garage?" (PRD §6). Private items are counted, never named.
struct ListRoomIntent: AppIntent {
    static let title: LocalizedStringResource = "What’s in a Place"
    static let description = IntentDescription("Lists what’s in a room, spot or box.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Place") var place: PlaceEntity

    init() {}
    init(place: PlaceEntity) { self.place = place }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = try IntentStore.context
        guard case .contents(_, let total, let groups)? = FindService(context: context).contents(of: place.id) else {
            throw IntentError.notFound
        }
        let answer = Self.answer(name: place.name, total: total, groups: groups)
        return .result(value: answer, dialog: "\(answer)")
    }

    static func answer(name: String, total: Int, groups: [ContentsGroup]) -> String {
        guard total > 0 else { return String(localized: "Nothing in \(name) yet.") }
        let names = groups.flatMap(\.itemNames)
        let hidden = total - names.count
        var list = names.prefix(10).joined(separator: ", ")
        if names.count > 10 { list += String(localized: ", and \(names.count - 10) more") }
        if hidden > 0 {
            let privateCount = String(localized: "\(hidden) private items")
            list = list.isEmpty ? privateCount : String(localized: "\(list), plus \(privateCount)")
        }
        return String(localized: "\(total) things in \(name): \(list).")
    }
}

/// "Add an item to Nook": opens the editor with the name, and the place when given (F2).
/// The Free tier's limit is checked on Save, as anywhere else (D58).
struct AddItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Item"
    static let description = IntentDescription("Opens Nook & Cranny to add something, with its name filled in.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Name") var name: String?
    @Parameter(title: "Place") var place: PlaceEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentStore.router?.newItem = NewItemRequest(name: name ?? "", place: place?.id)
        return .result()
    }
}

/// Room scan (C-02) from Siri, Shortcuts and Spotlight. The controls open `nook://scan`.
struct ScanRoomIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a Room"
    static let description = IntentDescription("Opens the camera to add a room’s things from one photo.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentStore.router?.link = .scan
        return .result()
    }
}

/// The phrases Siri knows without setup (04 §8). Every one names Nook.
struct NookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FindItemIntent(), phrases: [
            "Where is my \(\.$item) in \(.applicationName)",
            "Find \(\.$item) in \(.applicationName)",
            "Find something in \(.applicationName)",
        ], shortTitle: "Find Item", systemImageName: "magnifyingglass")
        AppShortcut(intent: MoveItemIntent(), phrases: [
            "Move \(\.$item) in \(.applicationName)",
            "Move something in \(.applicationName)",
        ], shortTitle: "Move Item", systemImageName: "arrow.up.and.down.and.arrow.left.and.right")
        AppShortcut(intent: ListRoomIntent(), phrases: [
            "What’s in \(\.$place) in \(.applicationName)",
            "What’s in a room in \(.applicationName)",
        ], shortTitle: "What’s in a Place", systemImageName: "square.grid.2x2")
        AppShortcut(intent: AddItemIntent(), phrases: [
            "Add an item to \(.applicationName)",
        ], shortTitle: "Add Item", systemImageName: "plus")
        AppShortcut(intent: ScanRoomIntent(), phrases: [
            "Scan a room with \(.applicationName)",
        ], shortTitle: "Scan a Room", systemImageName: "camera.viewfinder")
    }
}

/// Spotlight and Shortcuts open an item or place through these (04 §8). A Private item can't
/// get here: it's never an entity.
struct OpenItemIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Item"
    @Parameter(title: "Item") var target: ItemEntity

    init() {}
    init(target: ItemEntity) { self.target = target }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentStore.router?.link = .item(target.id)
        return .result()
    }
}

struct OpenPlaceIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Place"
    @Parameter(title: "Place") var target: PlaceEntity

    init() {}
    init(target: PlaceEntity) { self.target = target }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentStore.router?.link = .room(target.id)
        return .result()
    }
}
