import SwiftUI
import NookUI

/// H-01. P1 shows the empty state; rooms arrive in P2 and its Scan a Room action with
/// capture in P6, so there's no button yet rather than a dead end.
struct HomeScreen: View {
    var body: some View {
        TabRoot("Home") {
            EmptyStateView(.shelfWaiting,
                           title: Text("Let’s start with one room."),
                           message: Text("Your rooms and everything in them will show up here."))
        }
    }
}

#Preview { HomeScreen().nookAccent(.terracotta) }
