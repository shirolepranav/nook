import SwiftData

extension ModelContext {
    /// D35: SwiftData's own undo of a delete is lost at the next save (the restored rows
    /// vanish), so hard deletes register an undo that rebuilds what they removed instead.
    /// ponytail: no redo of a delete; add one if ⇧⌘Z ever needs it.
    @MainActor
    func deleteWithUndo(_ model: some PersistentModel, restore: @escaping (ModelContext) -> Void) {
        let undo = undoManager
        undo?.disableUndoRegistration()
        delete(model)
        processPendingChanges()
        undo?.enableUndoRegistration()
        undo?.registerUndo(withTarget: self) { context in
            MainActor.assumeIsolated { restore(context) }
        }
    }
}
