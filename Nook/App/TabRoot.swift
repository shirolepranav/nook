import SwiftUI
import NookUI

/// The frame every tab root shares: its own navigation stack (01 §1.1), a large title,
/// the warm canvas, content capped at the readable width on wide windows (D29), and the
/// Capture button on the root only, so pushed screens don't inherit it (D32).
struct TabRoot<Content: View>: View {
    let title: LocalizedStringKey
    let showsCapture: Bool
    let content: Content

    init(_ title: LocalizedStringKey, showsCapture: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsCapture = showsCapture
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s3) { content }
                    .padding(NookSpace.s2)
                    .frame(maxWidth: NookLayout.readableWidth)
                    .frame(maxWidth: .infinity)
            }
            // The floating Capture button never hides the end of the content.
            .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
            .background(NookColor.canvas)
            .captureButton(isShown: showsCapture)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.large)
        }
    }
}
