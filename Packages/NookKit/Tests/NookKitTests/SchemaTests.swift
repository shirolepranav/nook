import Foundation
import SwiftData
import Testing
@testable import NookKit

// The CloudKit-safe rules (D8, data-model-change skill), checked on the real schema so a
// future model can't break sync silently: CloudKit only fails at runtime.

private let schema = Schema(versionedSchema: NookSchemaV1.self)

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
