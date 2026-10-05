import SwiftUI
import NookUI

/// F-01. The search field lives in the Find tab (system search role, D2). Results and
/// answer cards arrive in P5.
struct FindScreen: View {
    @State private var query = ""
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        // On compact width the search field sits at the bottom, where Capture would go;
        // the iPhone Find boards leave Capture out, the iPad board keeps it (D32).
        TabRoot("Find", showsCapture: sizeClass == .regular) {
            EmptyStateView(.drawerEmpty,
                           title: Text("Nothing to find yet."),
                           message: Text("Add a few things and Nook will tell you where they are."))
        }
        .searchable(text: $query, prompt: Text("Search your things"))
    }
}

#Preview { FindScreen().nookAccent(.terracotta) }
