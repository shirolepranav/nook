import Foundation
import SwiftData
import Testing
@testable import NookKit

// The CloudKit-safe rules (D8, data-model-change skill), checked on the real schema so a
// future model can't break sync silently: CloudKit only fails at runtime.

private let schema = Schema(versionedSchema: NookSchemaV2.self)

@Test(arguments: schema.entities.map(\.name))
func entityIsCloudKitSafe(name: String) throws {
    let entity = try #require(schema.entitiesByName[name])
    for attribute in entity.attributes {
        #expect(attribute.isOptional || attribute.defaultValue != nil,
                "\(name).\(attribute.name) needs a default or must be optional")
        #expect(!attribute.isUnique, "\(name).\(attribute.name) can't be unique; identity is id: UUID")
    }
    for relationship in entity.relationships {
        #expect(relationship.isOptional, "\(name).\(relationship.name) must be optional")
        #expect(relationship.inverseName != nil, "\(name).\(relationship.name) needs an inverse")
        #expect(relationship.deleteRule != .deny, "\(name).\(relationship.name) can't use .deny")
    }
    #expect(entity.attributesByName["id"] != nil, "\(name) needs an app-owned id: UUID")
}

@Test func schemaHasEveryEntity() {
    // 04 §4 plus Warranty (D21) and SavedSearch (D46).
    #expect(Set(schema.entities.map(\.name)) ==
            ["Room", "Spot", "Item", "Photo", "Receipt", "Warranty", "LocationEvent", "Loan", "SavedSearch"])
}

// D53: V1 stores (P2–P7) open and migrate to V2, keeping their items.
@Test func v1StoreMigratesToV2() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "../../../../Fixtures/stores/v1.store").standardized
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
    try FileManager.default.copyItem(at: fixture, to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let schema = Schema(versionedSchema: NookSchemaV2.self)
    let container = try ModelContainer(for: schema, migrationPlan: NookMigrationPlan.self,
                                       configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    let items = try ModelContext(container).fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.name)]))
    #expect(items.map(\.name) == ["Kettle", "Toaster"])
    #expect(items.allSatisfy { $0.condition == "" && $0.itemCondition == nil })
    #expect(items.first?.room?.name == "Kitchen")
}
