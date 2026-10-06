import SwiftUI
import NookKit
import NookUI

extension View {
    /// The floating Capture button, bottom trailing in this screen's content (D26). It sits in
    /// the content column, so on regular width it's never over the sidebar (01 §1.5). Tab roots
    /// and Home's Room, Spot and Item screens show it; other pushed screens don't (D32).
    /// `location` is where Add Item puts new items when opened from a room or spot (C-01).
    func captureButton(isShown: Bool = true, at location: Location? = nil) -> some View {
        modifier(CaptureOverlay(isShown: isShown, location: location))
    }
}

/// D32: an overlay on each tab's content, not `tabViewBottomAccessory`, which Apple meant
/// for ongoing content like Now Playing and which D26 rejected for taking content space.
private struct CaptureOverlay: ViewModifier {
    let isShown: Bool
    let location: Location?
    @State private var showsMenu = false
    @State private var choseAddItem = false
    @State private var addsItem = false

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isShown {
                captureButton
            }
        }
        .quickAdd(isPresented: $addsItem, at: location)
        .onChange(of: showsMenu) { _, shows in
            guard !shows, choseAddItem else { return }
            choseAddItem = false
            // ponytail: waits out the menu's dismissal before the camera presents; use an
            // onDismiss if popovers ever get one.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                addsItem = true
            }
        }
    }

    private var captureButton: some View {
        CaptureButton { showsMenu = true }
            .padding(NookSpace.s2)
            // C-01: a popover anchored to the button on regular width, a medium sheet on
            // compact (01 §1.5, D29).
            .popover(isPresented: $showsMenu) {
                CaptureMenu {
                    choseAddItem = true
                    showsMenu = false
                }
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.medium])
            }
    }
}

/// C-01's four choices. Add item works from P3 (C-05, D37); the scanners arrive in P6, so
/// their rows show what's coming but can't be chosen yet. A plain stack, not a List, so the
/// popover sizes to fit all four rows.
struct CaptureMenu: View {
    var addItem: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture")
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NookSpace.s2)
                .accessibilityAddTraits(.isHeader)
            row("Scan room", "viewfinder").disabled(true)          // P6
            Divider()
            row("Add item", "plus", action: addItem)
            Divider()
            row("Scan receipt", "receipt").disabled(true)          // P6
            Divider()
            row("Scan barcode", "barcode.viewfinder").disabled(true)   // P6
        }
        .padding([.horizontal, .bottom], NookSpace.s2)
        .frame(minWidth: NookLayout.readableWidth / 2)
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.nookBody)
                .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
    }
}

#Preview { CaptureMenu() }
