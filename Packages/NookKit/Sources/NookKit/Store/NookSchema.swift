import SwiftData

/// Version 1 of the store. Every model is CloudKit-safe from the start, so turning on iCloud
/// sync for Pro (P11) needs no migration (D8): attributes optional or defaulted, relationships
/// optional with an inverse, no unique constraints, no `.deny`, order in `order` fields.
/// Change it only through the `data-model-change` skill: add `NookSchemaV2`, never edit V1
/// once it has shipped.
public enum NookSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Room.self, Spot.self, Item.self, Photo.self, Receipt.self, Warranty.self, LocationEvent.self, Loan.self,
         SavedSearch.self]
    }
}

public enum NookMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [NookSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

// The current schema's models, so the app writes `Room`, not `NookSchemaV1.Room`.
public typealias Room = NookSchemaV1.Room
public typealias Spot = NookSchemaV1.Spot
public typealias Item = NookSchemaV1.Item
public typealias Photo = NookSchemaV1.Photo
public typealias Receipt = NookSchemaV1.Receipt
public typealias Warranty = NookSchemaV1.Warranty
public typealias LocationEvent = NookSchemaV1.LocationEvent
public typealias Loan = NookSchemaV1.Loan
public typealias SavedSearch = NookSchemaV1.SavedSearch
