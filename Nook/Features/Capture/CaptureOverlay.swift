import SwiftUI
import NookUI

extension View {
    /// The floating Capture button, bottom trailing in this screen's content (D26). It sits in
    /// the content column, so on regular width it's never over the sidebar (01 §1.5). Tab roots
    /// and Home's Room, Spot and Item screens show it; other pushed screens don't (D32).
    func captureButton(isShown: Bool = true) -> some View {
        modifier(CaptureOverlay(isShown: isShown))
    }
}

/// D32: an overlay on each tab's content, not `tabViewBottomAccessory`, which Apple meant
/// for ongoing content like Now Playing and which D26 rejected for taking content space.
private struct CaptureOverlay: ViewModifier {
    let isShown: Bool
    @State private var showsMenu = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isShown {
                captureButton
            }
        }
    }

    private var captureButton: some View {
        CaptureButton { showsMenu = true }
            .padding(NookSpace.s2)
            // C-01: a popover anchored to the button on regular width, a medium sheet on
            // compact (01 §1.5, D29).
            .popover(isPresented: $showsMenu) {
                CaptureMenu()
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.medium])
            }
    }
}

/// C-01's four choices. P1 builds the presentation only: Add item arrives in P3, the
/// scanners in P6, so the rows show what's coming but can't be chosen yet. A plain stack,
/// not a List, so the popover sizes to fit all four rows.
struct CaptureMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture")
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NookSpace.s2)
                .accessibilityAddTraits(.isHeader)
            row("Scan room", "viewfinder")
            Divider()
            row("Add item", "plus")
            Divider()
            row("Scan receipt", "receipt")
            Divider()
            row("Scan barcode", "barcode.viewfinder")
        }
        .padding([.horizontal, .bottom], NookSpace.s2)
        .disabled(true)
        .frame(minWidth: NookLayout.readableWidth / 2)
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String) -> some View {
        Button {} label: {
            Label(title, systemImage: symbol)
                .font(.nookBody)
                .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget, alignment: .leading)
        }
    }
}

#Preview { CaptureMenu() }
