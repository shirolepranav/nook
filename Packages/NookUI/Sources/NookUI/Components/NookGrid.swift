import SwiftUI

/// The photo-card grid (03 §4, D29): adaptive columns of at least `cardMinWidth`, never
/// more than `maxGridColumns`, so 2 on compact iPhones and up to 6 on a wide iPad.
/// At accessibility text sizes it becomes a single column (03 §3: grids become lists).
public struct NookGrid<Content: View>: View {
    let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if typeSize.isAccessibilitySize {
            LazyVStack(spacing: NookSpace.s2) { content }
        } else {
            let columns = [GridItem(.adaptive(minimum: NookLayout.cardMinWidth), spacing: NookSpace.s2,
                                    alignment: .top)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: NookSpace.s2) { content }
                .frame(maxWidth: NookLayout.maxGridWidth)
        }
    }
}
