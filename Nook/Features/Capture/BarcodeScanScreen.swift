import SwiftUI
import SwiftData
import NookAI
import NookKit
import NookUI

/// C-07 Barcode scanner: the system scanner with a reticle, guidance and the torch. The first
/// valid read gives a light tap and returns the code. Typing it is always offered, and it's
/// the whole screen when the scanner or camera isn't there (D49). Full screen (01 §1.5).
struct BarcodeScanScreen: View {
    /// The code, or nil when cancelled.
    let finish: (String?) -> Void

    @State private var typesIt: Bool
    @State private var typed = ""
    @State private var torchOn = false
    @State private var reads = 0
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(finish: @escaping (String?) -> Void) {
        self.finish = finish
        _typesIt = State(initialValue: !Self.scannerAvailable)
    }

    private static var scannerAvailable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraDenied") { return false }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") { return true }
        #endif
        return BarcodeScanner.isAvailable && Camera.status != .denied
    }

    var body: some View {
        Group {
            if typesIt { manualEntry } else { scanner }
        }
        .nookHaptic(.tick, trigger: reads)
    }

    // MARK: Scanning

    private var scanner: some View {
        ZStack {
            feed.ignoresSafeArea()
            VStack(spacing: NookSpace.s3) {
                HStack {
                    CameraControl(Text("Cancel"), systemImage: "xmark") { finish(nil) }
                    Spacer()
                    if Camera.status == .ready {
                        CameraControl(Text("Torch"), systemImage: torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                      isOn: torchOn) {
                            torchOn.toggle()
                            CaptureSession.setDefaultTorch(torchOn)   // the scanner has no torch of its own (D49)
                        }
                    }
                }
                Spacer()
                RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous)
                    .strokeBorder(.primary, lineWidth: NookSpace.half)   // white: the camera chrome is dark
                    .aspectRatio(2, contentMode: .fit)
                    .frame(maxWidth: NookLayout.readableWidth / 1.5)
                    .accessibilityHidden(true)
                Text("Line up the barcode inside the frame.")
                    .font(.nookBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NookSpace.s2)
                    .padding(.vertical, NookSpace.s1)
                    .glassEffect(.regular, in: .capsule)   // a floating camera control (03 §6.3)
                Spacer()
                Button("Type It Instead") { typesIt = true }
                    .font(.nookHeadline)
                    .frame(minHeight: NookLayout.cameraControlSize)
                    .buttonStyle(.glass)
            }
            .padding(NookSpace.s2)
        }
        .background(NookColor.cameraFeed)
        .environment(\.colorScheme, .dark)
        .onDisappear { if torchOn { CaptureSession.setDefaultTorch(false) } }
    }

    @ViewBuilder
    private var feed: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") {
            NookColor.cameraFeed.task {
                try? await Task.sleep(for: .seconds(1))
                read(CaptureFixtures.barcode)
            }
        } else {
            BarcodeScanner(found: read)
        }
        #else
        BarcodeScanner(found: read)
        #endif
    }

    private func read(_ code: String) {
        reads += 1
        finish(code)
    }

    // MARK: Typing it

    private var manualEntry: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s2) {
                    NookTextField(Text("Barcode"), text: $typed, prompt: Text("The numbers under the bars"),
                                  helper: checkHelper)
                        .keyboardType(.numberPad)
                        .focused($fieldFocused)
                        .fontDesign(.monospaced)
                    if !Self.scannerAvailable {
                        Label("The scanner isn’t available here, so type the numbers in.", systemImage: "barcode")
                            .font(.nookFootnote)
                            .foregroundStyle(NookColor.textSecondary)
                    }
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(NookColor.canvas)
            .navigationTitle("Barcode")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { finish(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish(typed.trimmingCharacters(in: .whitespaces)) }
                        .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { fieldFocused = true }
        }
    }

    /// Retail barcodes carry a check digit; a mismatch is usually a typo. It still saves.
    private var checkHelper: Text? {
        let digits = typed.filter(\.isNumber)
        guard [8, 12, 13].contains(digits.count), digits.count == typed.count, !EAN.isValid(typed) else { return nil }
        return Text("Those numbers don’t add up. Check them against the label.")
    }
}

extension View {
    /// C-07 from C-01: scan, then "You have this" when an item has that barcode, or a new
    /// item with the barcode filled in. There's no lookup: Nook has no network (D48).
    func barcodeScan(isPresented: Binding<Bool>, at location: Location? = nil) -> some View {
        modifier(BarcodeScanFlow(isPresented: isPresented, location: location))
    }
}

private struct BarcodeScanFlow: ViewModifier {
    @Binding var isPresented: Bool
    let location: Location?

    @State private var match: Item?
    @State private var scanned = ""
    @State private var opened: Item?
    @State private var newItem: ItemDraft?
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: found) {
                BarcodeScanScreen { code in
                    scanned = code ?? ""
                    isPresented = false
                }
            }
            .confirmationDialog(Text("You have this"), isPresented: Binding { match != nil } set: { if !$0 { match = nil } },
                                titleVisibility: .visible, presenting: match) { item in
                Button("Open \(item.name)") { opened = item }
                Button("Add Another") { addNew() }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text(verbatim: ([item.name] + (Location(of: item)?.names.prefix(1) ?? [])).joined(separator: " · "))
            }
            .sheet(item: $opened) { item in
                NavigationStack {
                    ItemDetailScreen(item: item)
                        .itemNavigation()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { opened = nil } }
                        }
                }
            }
            .newItemEditor($newItem)
    }

    /// After the scanner closes, so the dialog isn't lost with it (P5: alerts after onDismiss).
    private func found() {
        let code = scanned
        scanned = ""
        guard !code.isEmpty else { return }
        if let item = try? ItemService(context: context).item(withBarcode: code) {
            match = item
        } else {
            addNew(code)
        }
    }

    private func addNew(_ code: String? = nil) {
        var draft = ItemDraft(currencyCode: HomeCurrency.code, location: location)
        draft.barcode = code ?? match?.barcode ?? ""
        match = nil
        newItem = draft
    }
}
