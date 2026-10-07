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
    @State private var chosen: CaptureMenu.Choice?
    @State private var addsItem = false
    @State private var scansRoom = false
    @State private var receiptSource: ReceiptSource?
    @State private var scansBarcode = false
    @State private var newItem: ItemDraft?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isShown {
                captureButton
            }
        }
        .quickAdd(isPresented: $addsItem, at: location)
        .roomScan(isPresented: $scansRoom, at: location)
        // C-06 from C-01: the review, then I-02 for a new item with the receipt attached.
        .receiptScan($receiptSource) { result in
            var draft = ItemDraft(currencyCode: HomeCurrency.code, location: location)
            result.apply(to: &draft)
            newItem = draft
        }
        .newItemEditor($newItem)
        .barcodeScan(isPresented: $scansBarcode, at: location)
        .onChange(of: showsMenu) { _, shows in
            guard !shows, let choice = chosen else { return }
            chosen = nil
            // ponytail: waits out the menu's dismissal before the camera presents; use an
            // onDismiss if popovers ever get one.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                switch choice {
                case .scanRoom: scansRoom = true
                case .addItem: addsItem = true
                case .scanReceipt: receiptSource = ReceiptScanAvailability.camera ? .camera : .files
                case .scanBarcode: scansBarcode = true
                }
            }
        }
    }

    private var captureButton: some View {
        CaptureButton { showsMenu = true }
            .padding(NookSpace.s2)
            // C-01: a popover anchored to the button on regular width, a medium sheet on
            // compact (01 §1.5, D29).
            .popover(isPresented: $showsMenu) {
                CaptureMenu { choice in
                    chosen = choice
                    showsMenu = false
                }
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.medium])
            }
    }
}

/// C-01's four choices. A plain stack, not a List, so the popover sizes to fit all four rows.
struct CaptureMenu: View {
    enum Choice { case scanRoom, addItem, scanReceipt, scanBarcode }

    var choose: (Choice) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture")
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NookSpace.s2)
                .accessibilityAddTraits(.isHeader)
            row("Scan room", "viewfinder") { choose(.scanRoom) }
            Divider()
            row("Add item", "plus") { choose(.addItem) }
            Divider()
            row("Scan receipt", "receipt") { choose(.scanReceipt) }
            Divider()
            row("Scan barcode", "barcode.viewfinder") { choose(.scanBarcode) }
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

extension View {
    /// I-02 for a new item that starts filled in (C-06, C-07, Open in Nook), then the
    /// "Saved to Kitchen." toast.
    func newItemEditor(_ draft: Binding<ItemDraft?>) -> some View {
        modifier(NewItemEditor(draft: draft))
    }
}

private struct NewItemEditor: ViewModifier {
    @Binding var draft: ItemDraft?
    @State private var start: Start?
    @State private var toast: ToastMessage?

    private struct Start: Identifiable {
        let id = UUID()
        let draft: ItemDraft
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: draft) { _, new in
                guard let new else { return }
                draft = nil
                start = Start(draft: new)
            }
            .sheet(item: $start) { start in
                ItemEditor(draft: start.draft) { item in
                    toast = item.room.map { ToastMessage("Saved to \($0.name).") } ?? ToastMessage("Saved.")
                }
            }
            .toast($toast)
    }
}
