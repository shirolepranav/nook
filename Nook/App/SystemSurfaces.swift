import AppIntents
import CoreSpotlight
import SwiftData
import WidgetKit
import OSLog
import NookKit

/// Keeps what Nook shows outside the app current (04 §8): Spotlight's items and places, and
/// the widgets. One observer after every save, like Find's index (D61), so moves, edits,
/// restores, dedupe and iCloud imports all count, whichever service made them.
@MainActor
final class SystemSurfaces {
    private let container: ModelContainer
    private var pending: Task<Void, Never>?
    private var indexed: (items: Set<UUID>, places: Set<UUID>)?
    private static let log = Logger(subsystem: "pranav.nook", category: "Nook.surfaces")

    init(container: ModelContainer) {
        self.container = container
    }

    /// Run from the shell's `.task`: now, then 300 ms after each run of saves.
    func keepCurrent() async {
        await refresh()
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    // ponytail: rebuilds every entity on each save (~5k items); diff by fingerprint if
    // Instruments flags it in P13.
    func refresh() async {
        WidgetCenter.shared.reloadAllTimelines()
        let container = container
        let (items, places) = await Task.detached(priority: .utility) {
            Self.entities(in: ModelContext(container))
        }.value
        let index = CSSearchableIndex.default()
        do {
            if let indexed {
                let goneItems = indexed.items.subtracting(items.map(\.id))
                let gonePlaces = indexed.places.subtracting(places.map(\.id))
                if !goneItems.isEmpty { try await index.deleteAppEntities(identifiedBy: Array(goneItems), ofType: ItemEntity.self) }
                if !gonePlaces.isEmpty { try await index.deleteAppEntities(identifiedBy: Array(gonePlaces), ofType: PlaceEntity.self) }
            } else {
                // First pass after launch: start clean, so nothing from an earlier run lingers.
                try await index.deleteAppEntities(ofType: ItemEntity.self)
                try await index.deleteAppEntities(ofType: PlaceEntity.self)
            }
            try await index.indexAppEntities(items)
            try await index.indexAppEntities(places)
            indexed = (Set(items.map(\.id)), Set(places.map(\.id)))
            Self.log.debug("Spotlight: \(items.count) items, \(places.count) places")
        } catch {
            Self.log.error("Spotlight indexing failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// What Spotlight may show: live items that aren't Private (PRD §9), and every place.
    nonisolated static func entities(in context: ModelContext) -> ([ItemEntity], [PlaceEntity]) {
        let items = (try? context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.deletedAt == nil && !$0.isPrivate }))) ?? []
        let places = (try? PlaceQuery.all(in: context)) ?? []
        return (items.map(ItemEntity.init), places.map(PlaceEntity.init))
    }
}
