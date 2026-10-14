import CoreData
import SwiftData

/// The one SwiftData store, in the App Group so widgets and App Intents read it too (PRD §8).
public enum NookStore {
    /// `inMemory` for tests and previews. `sync` mirrors the store to the user's private
    /// CloudKit database (Pro, S-03, D8). Only a build with the iCloud entitlement may pass it:
    /// without one, CloudKit traps (D59).
    /// `readOnly` is the widgets' view of the same file: they never write (04 §8), and never
    /// mirror, so the app alone talks to iCloud.
    public static func makeContainer(inMemory: Bool = false, sync: Bool = false, readOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: NookSchemaV2.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, allowsSave: !readOnly, groupContainer: .identifier(NookKit.appGroupID),
                                 cloudKitDatabase: sync && !readOnly ? .private(SyncSettings.containerID) : .none)
        return try ModelContainer(for: schema, migrationPlan: NookMigrationPlan.self,
                                  configurations: configuration)
    }

    #if DEBUG
    /// Creates the CloudKit record types for the current schema in the Development
    /// environment. SwiftData has no call for it, so it goes through Core Data on a
    /// throwaway store (D59). Run once per schema change, from a device or simulator signed
    /// into iCloud, with `-initializeCloudKitSchema YES`; then deploy the schema to
    /// Production in the CloudKit Console before release.
    public static func initializeCloudKitSchema() throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: NookSchemaV2.models) else { return }
        let url = FileManager.default.temporaryDirectory.appending(path: "NookSchema-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: SyncSettings.containerID)
        description.shouldAddStoreAsynchronously = false
        let container = NSPersistentCloudKitContainer(name: "NookSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        try container.initializeCloudKitSchema(options: [])
    }
    #endif
}
