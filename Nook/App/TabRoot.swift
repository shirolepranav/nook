import SwiftUI
import NookUI

/// The frame every tab root shares: its own navigation stack (01 §1.1), a large title,
/// the warm canvas, content capped at the readable width on wide windows (D29), and the
/// Capture button on the root only, so pushed screens don't inherit it (D32).
struct TabRoot<Content: View>: View {
    let title: LocalizedStringKey
    let showsCapture: Bool
    let content: Content
    /// The tab this root belongs to, so `AppRouter` requests for it land on this stack.
    let tab: AppTab?
    @State private var path = NavigationPath()
    @Environment(AppRouter.self) private var router: AppRouter?

    init(_ title: LocalizedStringKey, showsCapture: Bool = true, tab: AppTab? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsCapture = showsCapture
        self.tab = tab
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
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
            .itemNavigation()   // I-01 opens with a zoom from any item card in this tab
        }
        .onChange(of: router?.request?.id, initial: true) {
            guard let request = router?.request, request.tab == tab else { return }
            path = NavigationPath()
            switch request.destination {
            case .item(let item): path.append(item)
            case .report(let route): path.append(route)
            }
            router?.request = nil
        }
    }
}
