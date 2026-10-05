import SwiftUI
import NookUI

/// R-01. Warranties, Lent out and the insurance report arrive in P7 and P10.
struct ReportsScreen: View {
    var body: some View {
        TabRoot("Reports") {
            EmptyStateView(.receiptRibbon,
                           title: Text("Reports live here."),
                           message: Text("Warranties, lent things and your insurance report will appear as you add items."))
        }
    }
}

#Preview { ReportsScreen().nookAccent(.terracotta) }
