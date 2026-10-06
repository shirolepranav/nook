import SwiftUI

/// Keyboard shortcuts (01 §1.5, D29). In a CommandMenu they also appear in the iPad menu
/// bar (D30). The system adds File, Edit (Undo, Redo, Cut, Copy, Paste), View, Window and Help.
struct NookCommands: Commands {
    @FocusedValue(\.selectedTab) private var selectedTab

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
            Button("Add Item") {}.keyboardShortcut("n").disabled(true)                     // C-05, P3
            Button("Scan Room") {}.keyboardShortcut("n", modifiers: [.command, .shift])    // C-02, P6
                .disabled(true)
            Button("Edit") {}.keyboardShortcut("e").disabled(true)                         // P2, P3
            // ⇧⌘M, not ⌘M: iPadOS keeps ⌘M for minimizing a window (D30).
            Button("Move") {}.keyboardShortcut("m", modifiers: [.command, .shift])         // I-04, P4
                .disabled(true)
            Button("Delete") {}.keyboardShortcut(.delete).disabled(true)                   // P3
        }
    }
}
