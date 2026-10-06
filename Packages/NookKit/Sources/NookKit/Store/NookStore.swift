import SwiftData

/// The one SwiftData store, in the App Group so widgets and App Intents read it too (PRD §8).
public enum NookStore {
    /// `inMemory` for tests and previews. CloudKit stays off until Pro sync (P11, D8).
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NookSchemaV1.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(NookKit.appGroupID),
                                 cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: NookMigrationPlan.self,
                                  configurations: configuration)
    }
}
