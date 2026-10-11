import SwiftData

/// Every version is CloudKit-safe, so turning on iCloud sync for Pro (P11) needs no migration
/// (D8): attributes optional or defaulted, relationships optional with an inverse, no unique
/// constraints, no `.deny`, order in `order` fields. Change the schema only through the
/// `data-model-change` skill: add a new version, never edit one that has shipped.
///
/// Version 1, P2–P7. Its models are frozen in `NookSchemaV1.swift`.
public enum NookSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Room.self, Spot.self, Item.self, Photo.self, Receipt.self, Warranty.self, LocationEvent.self, Loan.self,
         SavedSearch.self]
    }
}

/// Version 2 (P8): `Item.condition` (D53).
public enum NookSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Room.self, Spot.self, Item.self, Photo.self, Receipt.self, Warranty.self, LocationEvent.self, Loan.self,
         SavedSearch.self]
    }
}

public enum NookMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NookSchemaV1.self, NookSchemaV2.self] }
    public static var stages: [MigrationStage] {
        // Additive: a defaulted attribute (D53).
        [.lightweight(fromVersion: NookSchemaV1.self, toVersion: NookSchemaV2.self)]
    }
}

// The current schema's models, so the app writes `Room`, not `NookSchemaV2.Room`.
public typealias Room = NookSchemaV2.Room
public typealias Spot = NookSchemaV2.Spot
public typealias Item = NookSchemaV2.Item
public typealias Photo = NookSchemaV2.Photo
public typealias Receipt = NookSchemaV2.Receipt
public typealias Warranty = NookSchemaV2.Warranty
public typealias LocationEvent = NookSchemaV2.LocationEvent
public typealias Loan = NookSchemaV2.Loan
public typealias SavedSearch = NookSchemaV2.SavedSearch
