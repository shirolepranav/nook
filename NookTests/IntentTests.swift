import Testing
import Foundation
import SwiftData
import NookKit
@testable import Nook

/// App Intents (04 §8, 05 §1): answers come from records, nothing moves without the
/// confirmation, and Private items never reach Siri, Shortcuts or Spotlight (PRD §9).
@MainActor
@Suite(.serialized)   // IntentStore is one shared store
struct IntentTests {
    let container = PreviewStore.seeded(.lived)
    var context: ModelContext { container.mainContext }

    init() { IntentStore.container = container }

    func item(_ name: String) throws -> Item {
        try #require(try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.name == name })).first)
    }

    @Test func findAnswersFromTheRecords() async throws {
        let found = try await ItemQuery().entities(matching: "espreso")   // a typo, as Find allows
        let espresso = try #require(found.first)
        #expect(espresso.name == "Espresso machine")
        let answer = FindItemIntent.answer(for: try item("Espresso machine"))
        #expect(answer.hasPrefix("Espresso machine is in Kitchen → Counter. Last confirmed"))
    }

    @Test func privateItemsAreNeverEntities() async throws {
        let ring = try item("Grandma’s ring")
        #expect(try await ItemQuery().entities(matching: "ring").isEmpty)
        #expect(try await ItemQuery().entities(for: [ring.id]).isEmpty)
        #expect(try await ItemQuery().suggestedEntities().allSatisfy { $0.id != ring.id })
        let (spotlight, _) = SystemSurfaces.entities(in: context)
        #expect(!spotlight.contains { $0.id == ring.id })
        #expect(spotlight.contains { $0.name == "Cordless drill" })
    }

    @Test func listRoomCountsPrivateItemsWithoutNamingThem() async throws {
        let bedroom = try #require(try await PlaceQuery().entities(matching: "Bedroom").first)
        guard case .contents(_, let total, let groups)? = FindService(context: context).contents(of: bedroom.id) else {
            Issue.record("No contents"); return
        }
        let answer = ListRoomIntent.answer(name: bedroom.name, total: total, groups: groups)
        #expect(answer.contains("Winter coat"))
        #expect(!answer.contains("Passport") && !answer.contains("ring"))
        #expect(answer.contains("2 private items"))
    }

    @Test func moveWritesOneSiriEventThroughLocationService() throws {
        let drill = try item("Cordless drill")
        let before = drill.events?.count ?? 0
        let kitchenID = try #require(try RoomService(context: context).rooms().first { $0.name == "Kitchen" }?.id)
        let kitchen = try #require(PlaceQuery.location(kitchenID, in: context))
        try MoveItemIntent.move(drill, to: kitchen, in: context)
        #expect(drill.room?.name == "Kitchen")
        #expect((drill.events?.count ?? 0) == before + 1)
        #expect(drill.events?.max { $0.date < $1.date }?.source == .siri)
    }

    @Test func placesCoverRoomsSpotsAndContainers() throws {
        let paths = try PlaceQuery.all(in: context).map(\.path)
        #expect(paths.contains("Garage"))
        #expect(paths.contains("Garage → Metal shelf"))
        #expect(paths.contains("Garage → Metal shelf → Box 14"))
    }
}
