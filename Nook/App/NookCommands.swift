import SwiftUI

/// Keyboard shortcuts (01 §1.5, D29). In a CommandMenu they also appear in the iPad menu
/// bar (D30). The system adds File, Edit (Undo, Redo, Cut, Copy, Paste), View, Window and Help.
struct NookCommands: Commands {
    @FocusedValue(\.selectedTab) private var selectedTab
    @FocusedValue(\.editsSelectedRoom) private var editsSelectedRoom
    @FocusedValue(\.itemCommands) private var itemCommands
    @FocusedValue(\.addItem) private var addItem

    private func show(_ tab: AppTab) { selectedTab?.wrappedValue = tab }

    var body: some Commands {
        // D30: the system's "Settings…" (⌘,) would open the iPad Settings app.
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { show(.settings) }
                .keyboardShortcut(",")
        }
        CommandMenu("Nook") {
            Button("Home") { show(.home) }.keyboardShortcut("1")
            Button("Find") { show(.find) }.keyboardShortcut("2")
            Button("Reports") { show(.reports) }.keyboardShortcut("3")
            Button("Settings") { show(.settings) }.keyboardShortcut("4")
            Divider()
            Button("Search") { show(.find) }.keyboardShortcut("f")
            Divider()
            // Each command turns on with its feature.
            Button("Add Item") { addItem?.run() }.keyboardShortcut("n").disabled(addItem == nil)   // C-05
            Button("Scan Room") {}.keyboardShortcut("n", modifiers: [.command, .shift])    // C-02, P6
                .disabled(true)
            // The item on screen first, else the room selected in the sidebar.
            Button("Edit") {
                if let edit = itemCommands?.edit { edit() } else { editsSelectedRoom?.wrappedValue = true }
            }
            .keyboardShortcut("e")
            .disabled(itemCommands?.edit == nil && editsSelectedRoom == nil)
            // ⇧⌘M, not ⌘M: iPadOS keeps ⌘M for minimizing a window (D30).
            Button("Move") { itemCommands?.move?() }                                      // I-04
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(itemCommands?.move == nil)
            Button("Delete") { itemCommands?.delete() }                                    // to Recently Deleted
                .keyboardShortcut(.delete)
                .disabled(itemCommands == nil)
        }
    }
}
