import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import NookAI
import NookKit
import NookUI

/// Where a receipt comes from (C-06): the document camera, Files, Photos, or a file opened
/// in Nook from another app (D48).
enum ReceiptSource: Identifiable, Equatable {
    case camera, files, photos, file(URL)
    var id: String { "\(self)" }
}

/// What the receipt review hands back: the receipt on disk with its text, and whichever
/// fields the user filled by tapping.
struct ReceiptScanResult {
    var receipt: ItemDraft.DraftReceipt
    var store = ""
    var date: Date?
    var price: Decimal?
    var currencyCode: String?

    /// Fills a draft, leaving alone what the user didn't choose.
    func apply(to draft: inout ItemDraft) {
        draft.receipts.append(receipt)
        if !store.isEmpty { draft.store = store }
        if let date { draft.purchaseDate = date }
        if let price {
            draft.price = price
            if let currencyCode { draft.currencyCode = currencyCode }
        }
    }
}

/// Whether Scan Receipt can open the document camera, or the fixture in UI tests.
enum ReceiptScanAvailability {
    @MainActor static var camera: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") { return true }
        #endif
        return DocumentScanner.isAvailable
    }
}

extension View {
    /// C-06: gets a receipt from `source`, saves it (D40), then opens the review. `done` gets
    /// the result after Save Receipt; Cancel removes the file again.
    func receiptScan(_ source: Binding<ReceiptSource?>, done: @escaping (ReceiptScanResult) -> Void) -> some View {
        modifier(ReceiptScanFlow(source: source, done: done))
    }
}

/// A saved receipt and its pages, ready to read.
struct ReceiptPages: Identifiable {
    let id = UUID()
    let receipt: ItemDraft.DraftReceipt
    let pages: [CGImage]
}

private struct ReceiptScanFlow: ViewModifier {
    @Binding var source: ReceiptSource?
    let done: (ReceiptScanResult) -> Void

    @State private var showsCamera = false
    @State private var importsFile = false
    @State private var picksPhoto = false
    @State private var picked: PhotosPickerItem?
    @State private var review: ReceiptPages?
    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .onChange(of: source) { _, chosen in
                guard let chosen else { return }
                source = nil
                switch chosen {
                case .camera:
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture"),
                       let fixture = CaptureFixtures.receipt?.cgImage {
                        prepare(pages: [fixture]); return
                    }
                    #endif
                    if DocumentScanner.isAvailable { showsCamera = true } else { importsFile = true }
                case .files: importsFile = true
                case .photos: picksPhoto = true
                case .file(let url): prepare(file: url)
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                DocumentScanner { pages in
                    showsCamera = false
                    if let pages, !pages.isEmpty { prepare(pages: pages) }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $importsFile, allowedContentTypes: [.pdf, .image]) { result in
                if case .success(let url) = result { prepare(file: url) }
            }
            .photosPicker(isPresented: $picksPhoto, selection: $picked, matching: .images)
            .onChange(of: picked) { _, item in
                guard let item else { return }
                picked = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { failed = true; return }
                    prepare(data: data)
                }
            }
            .fullScreenCover(item: $review) { pages in
                ReceiptScanScreen(pages: pages) { result in
                    review = nil
                    if let result { done(result) } else { BlobStore.shared.remove([pages.receipt.fileName], in: .receipts) }
                }
            }
            .alert(Text("That file can’t be added as a receipt. Try a photo or a PDF."), isPresented: $failed) {
                Button("OK") {}
            }
    }

    /// Document-camera pages: one page is a photo, several are one PDF (D48).
    private func prepare(pages: [CGImage]) {
        Task {
            let saved: ItemDraft.DraftReceipt? = await Task.detached {
                if pages.count == 1 {
                    guard let data = UIImage(cgImage: pages[0]).jpegData(compressionQuality: 0.9),
                          let fileName = try? BlobStore.shared.saveReceipt(data) else { return nil }
                    return .init(fileName: fileName, kind: .image)
                }
                let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".pdf")
                defer { try? FileManager.default.removeItem(at: url) }
                guard (try? Self.pdf(pages).write(to: url)) != nil,
                      let saved = try? BlobStore.shared.saveReceipt(from: url) else { return nil }
                return .init(fileName: saved.fileName, kind: .pdf)
            }.value
            if let saved { review = ReceiptPages(receipt: saved, pages: pages) } else { failed = true }
        }
    }

    private func prepare(file url: URL) {
        Task {
            let result: ReceiptPages? = await Task.detached {
                guard let saved = try? BlobStore.shared.saveReceipt(from: url) else { return nil }
                let stored = BlobStore.shared.url(for: saved.fileName, in: .receipts)
                let input = saved.isPDF ? DocumentInput(pdf: stored)
                                        : (try? Data(contentsOf: stored)).flatMap(DocumentInput.init(imageData:))
                guard let input else { return nil }
                return ReceiptPages(receipt: .init(fileName: saved.fileName, kind: saved.isPDF ? .pdf : .image),
                                    pages: input.pages)
            }.value
            if let result { review = result } else { failed = true }
        }
    }

    private func prepare(data: Data) {
        Task {
            let result: ReceiptPages? = await Task.detached {
                guard let fileName = try? BlobStore.shared.saveReceipt(data),
                      let input = DocumentInput(imageData: data) else { return nil }
                return ReceiptPages(receipt: .init(fileName: fileName, kind: .image), pages: input.pages)
            }.value
            if let result { review = result } else { failed = true }
        }
    }

    /// Each page at its own size, so the PDF reads like the paper.
    nonisolated private static func pdf(_ pages: [CGImage]) -> Data {
        let first = CGRect(x: 0, y: 0, width: pages[0].width, height: pages[0].height)
        return UIGraphicsPDFRenderer(bounds: first).pdfData { context in
            for page in pages {
                let bounds = CGRect(x: 0, y: 0, width: page.width, height: page.height)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                UIImage(cgImage: page).draw(in: bounds)
            }
        }
    }
}

/// C-06 review, Classic (01 C-06): the receipt with each recognized amount and date
/// highlighted. Tapping one drops it into its field and moves on to the next empty one; with
/// Store selected, the lines are tappable too and one sets it. The best guesses are highlighted
/// strongest, but nothing is filled until the user taps (PRD §5).
struct ReceiptScanScreen: View {
    let pages: ReceiptPages
    /// nil when cancelled.
    let finish: (ReceiptScanResult?) -> Void

    enum Field: CaseIterable { case store, date, price }

    @State private var reading: ReceiptReading?
    @State private var isReading = true
    @State private var page = 0
    @State private var field: Field = .date   // the numbers first; the store's name is usually plain
    @State private var store = ""
    @State private var date: Date?
    @State private var priceText = ""
    @State private var currencyCode = HomeCurrency.code
    @State private var used: Set<String> = []
    @State private var drops = 0
    @FocusState private var typing: Field?
    @Environment(\.windowSizeClass) private var windowSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            layout
                .background(NookColor.canvas)
                .navigationTitle("Receipt")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { finish(nil) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save Receipt", action: save)
                    }
                }
        }
        .nookHaptic(.selected, trigger: drops)
        .task {
            // D48: the one place receipts are read; P8 asks the router instead.
            reading = try? await NookAI.classic.readReceipt(DocumentInput(pages: pages.pages))
            if let code = reading?.currencyCode { currencyCode = code }
            isReading = false
        }
    }

    @ViewBuilder
    private var layout: some View {
        if windowSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 0) {
                ScrollView { paper.padding(NookSpace.s2) }
                Divider()
                ScrollView { fields.padding(NookSpace.s2) }
                    .frame(width: NookLayout.itemColumnWidth)
            }
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: NookSpace.s2) {
                    fields
                    paper
                }
                .padding(NookSpace.s2)
            }
        } else {
            // The fields stay in reach under the receipt while it scrolls.
            ScrollView { paper.padding(NookSpace.s2) }
                .safeAreaInset(edge: .bottom) {
                    fields
                        .padding(NookSpace.s2)
                        .background(NookColor.canvas)
                }
        }
    }

    // MARK: The receipt and its highlights

    private var paper: some View {
        VStack(spacing: NookSpace.s1) {
            Text(statusLine)
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)
            let image = pages.pages[page]
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay { highlights }
                .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                .warmShadow(.low)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Receipt, page \(page + 1)"))
            if pages.pages.count > 1 {
                HStack {
                    Button("Previous Page", systemImage: "chevron.left") { page -= 1 }.disabled(page == 0)
                    Spacer()
                    Text("Page \(page + 1) of \(pages.pages.count)").font(.nookMeta)
                    Spacer()
                    Button("Next Page", systemImage: "chevron.right") { page += 1 }.disabled(page == pages.pages.count - 1)
                }
                .labelStyle(.iconOnly)
                .frame(minHeight: NookLayout.minTapTarget)
            }
        }
        .frame(maxWidth: NookLayout.readableWidth)
        .frame(maxWidth: .infinity)
    }

    private var statusLine: LocalizedStringResource {
        if isReading { return "Reading the receipt…" }
        guard let reading, !reading.lines.isEmpty else { return "That receipt couldn’t be read. You can type the numbers in." }
        if field == .store { return "Tap the store’s name, or type it." }
        return reading.amounts.isEmpty && reading.dates.isEmpty
            ? "No numbers found. You can type them in."
            : "Tap a highlighted number to fill the field."
    }

    /// One tappable spot on the receipt.
    private struct Spot: Identifiable {
        let id: String
        let frame: CGRect
        let label: Text
        let isBest: Bool
        let isUsed: Bool
        /// Numbers win over a line they sit on.
        let isNumber: Bool
        let action: () -> Void
    }

    /// Printed lines sit closer than 44 pt, so tap areas would overlap. One layer takes the
    /// tap and picks the nearest highlight; the highlights themselves stay VoiceOver buttons.
    private var highlights: some View {
        GeometryReader { proxy in
            let spots = spots(in: proxy.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in nearest(to: point, in: spots)?.action() }
                    .accessibilityHidden(true)
                ForEach(spots) { spot in
                    ScanHighlight(spot.label, size: spot.frame.size, isBest: spot.isBest, isUsed: spot.isUsed,
                                  action: spot.action)
                        .allowsHitTesting(false)
                        .position(x: spot.frame.midX, y: spot.frame.midY)
                }
            }
        }
    }

    private func nearest(to point: CGPoint, in spots: [Spot]) -> Spot? {
        let reach = NookLayout.minTapTarget / 2
        func distance(_ frame: CGRect) -> CGFloat {
            hypot(max(frame.minX - point.x, 0, point.x - frame.maxX), max(frame.minY - point.y, 0, point.y - frame.maxY))
        }
        return spots.filter { distance($0.frame) <= reach }
            .min { (distance($0.frame), $0.isNumber ? 0 : 1) < (distance($1.frame), $1.isNumber ? 0 : 1) }
    }

    private func spots(in size: CGSize) -> [Spot] {
        guard let reading else { return [] }
        let place = { (box: CGRect) in
            CGRect(x: box.minX * size.width, y: box.minY * size.height, width: box.width * size.width,
                   height: box.height * size.height)
        }
        var spots: [Spot] = []
        if field == .store {
            // Lines with words near the top: the store's name is usually one of them.
            for (index, line) in reading.lines.prefix(10).enumerated()
            where line.page == page && line.text.filter(\.isLetter).count >= 3 {
                spots.append(Spot(id: "l\(index)", frame: place(line.box), label: Text(verbatim: line.text),
                                  isBest: line.text.localizedCaseInsensitiveContains(reading.store ?? "\u{0}"),
                                  isUsed: false, isNumber: false) { drop(.store, text: line.text) })
            }
        }
        for (index, candidate) in reading.dates.enumerated() where candidate.page == page {
            spots.append(Spot(id: "d\(index)", frame: place(candidate.box), label: Text("Date \(candidate.text)"),
                              isBest: index == 0, isUsed: used.contains("d\(index)"), isNumber: true) {
                used.insert("d\(index)")
                drop(.date, date: candidate.value)
            })
        }
        for (index, candidate) in reading.amounts.enumerated() where candidate.page == page {
            spots.append(Spot(id: "a\(index)", frame: place(candidate.box), label: Text("Amount \(candidate.text)"),
                              isBest: index == 0, isUsed: used.contains("a\(index)"), isNumber: true) {
                used.insert("a\(index)")
                drop(.price, amount: candidate.value)
            })
        }
        return spots
    }

    // MARK: Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            target(.store, Text("Store")) {
                TextField(text: $store, prompt: Text("Tap the name, or type it").foregroundStyle(NookColor.textSecondary)) {
                    Text("Store")
                }
                .focused($typing, equals: .store)
                .accessibilityLabel(Text("Store"))
            }
            target(.date, Text("Date")) {
                if let date {
                    HStack {
                        DatePicker(selection: Binding { date } set: { self.date = $0 }, displayedComponents: .date) {
                            Text("Date")
                        }
                        .labelsHidden()
                        Spacer(minLength: 0)
                        Button("Clear", systemImage: "xmark.circle.fill") { self.date = nil; field = .date }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(NookColor.textSecondary)
                            .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                            .accessibilityLabel(Text("Clear date"))
                    }
                } else {
                    Button { field = .date } label: {
                        Text("Tap a date").foregroundStyle(NookColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Date"))
                    .accessibilityValue(Text("Empty"))
                }
            }
            target(.price, Text("Price")) {
                HStack {
                    TextField(text: $priceText, prompt: Text("Tap a number").foregroundStyle(NookColor.textSecondary)) {
                        Text("Price")
                    }
                    .keyboardType(.decimalPad)
                    .focused($typing, equals: .price)
                    .font(.nookBody.monospacedDigit())
                    .accessibilityLabel(Text("Price"))
                    Text(verbatim: currencyCode).font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: NookLayout.readableWidth)
        .onChange(of: typing) { _, now in if let now { field = now } }
    }

    /// A field well that shows when it's the one a tap fills.
    private func target(_ which: Field, _ label: Text, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: NookSpace.s1) {
            label
                .font(.nookFootnote.weight(.semibold))
                .foregroundStyle(field == which ? AnyShapeStyle(.tint) : AnyShapeStyle(NookColor.textSecondary))
                .frame(minWidth: NookLayout.photoTileWidth / 1.5, alignment: .leading)
                .accessibilityHidden(true)
            content()
                .font(.nookBody)
        }
        .padding(.horizontal, NookSpace.s2)
        .frame(maxWidth: .infinity, minHeight: NookLayout.fieldHeight, alignment: .leading)
        .background(NookColor.surfaceSunken, in: RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
        .overlay {
            if field == which {
                RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
                    .strokeBorder(.tint, lineWidth: NookLayout.outlineWidth)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { field = which }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(field == which ? .isSelected : [])
    }

    // MARK: Drops

    /// A tapped value goes into the selected field when it fits there, else into the field it
    /// fits; then the next empty field is selected.
    private func drop(_ kind: Field, text: String? = nil, date dropped: Date? = nil, amount: Decimal? = nil) {
        switch kind {
        case .store: store = text?.trimmingCharacters(in: .whitespaces) ?? store
        case .date: date = dropped
        case .price: priceText = amount.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? priceText
        }
        drops += 1
        typing = nil
        field = Field.allCases.first(where: isEmpty) ?? kind
    }

    private func isEmpty(_ field: Field) -> Bool {
        switch field {
        case .store: store.trimmingCharacters(in: .whitespaces).isEmpty
        case .date: date == nil
        case .price: priceText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func save() {
        var result = ReceiptScanResult(receipt: pages.receipt)
        result.receipt.extractedText = reading?.text ?? ""
        result.store = store.trimmingCharacters(in: .whitespaces)
        result.date = date
        result.price = try? Decimal(priceText.trimmingCharacters(in: .whitespaces), format: .number)
        result.currencyCode = currencyCode
        finish(result)
    }
}
