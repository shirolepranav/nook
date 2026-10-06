import SwiftUI
import NookUI

/// Shown if the store can't open (01 §1.3: plain reason, reassurance, Retry). Rare: a full
/// disk, or a store from a newer version of Nook.
struct StoreErrorView: View {
    let retry: () -> Void

    var body: some View {
        ErrorStateView(symbol: "externaldrive.badge.exclamationmark",
                       title: Text("Nook couldn’t open your items"),
                       message: Text("Nothing has been deleted. Free up some storage or update Nook, then try again."),
                       retry: retry)
        .padding(NookSpace.s2)
        .frame(maxWidth: NookLayout.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NookColor.canvas)
    }
}

#Preview { StoreErrorView {}.nookAccent(.terracotta) }
