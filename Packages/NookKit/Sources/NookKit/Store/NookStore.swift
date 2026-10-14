import SwiftData

/// The one SwiftData store, in the App Group so widgets and App Intents read it too (PRD §8).
public enum NookStore {
    /// `inMemory` for tests and previews. `sync` mirrors the store to the user's private
    /// CloudKit database (Pro, S-03, D8). Only a build with the iCloud entitlement may pass it:
    /// without one, CloudKit traps (D59).
    public static func makeContainer(inMemory: Bool = false, sync: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NookSchemaV2.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(NookKit.appGroupID),
                                 cloudKitDatabase: sync ? .private(SyncSettings.containerID) : .none)
        return try ModelContainer(for: schema, migrationPlan: NookMigrationPlan.self,
                                  configurations: configuration)
    }
}
