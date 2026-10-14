import SwiftUI
import SwiftData
import Photos
import CoreImage.CIFilterBuiltins
import NookKit
import NookUI

/// The sizes H-06 prints: two common label sheets and a plain card (D28), in points.
enum LabelSize: String, CaseIterable, Identifiable {
    case shipping, address, card

    var id: String { rawValue }

    /// 72 points to the inch.
    var size: CGSize {
        switch self {
        case .shipping: CGSize(width: 288, height: 144)   // 2 × 4 in
        case .address: CGSize(width: 189, height: 72)     // 1 × 2⅝ in
        case .card: CGSize(width: 216, height: 288)       // 3 × 4 in
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .shipping: "2 × 4 in"
        case .address: "1 × 2⅝ in"
        case .card: "Plain card"
        }
    }
}

/// H-06 Box label: a QR code for `nook://spot/<qrID>` (D19) that the Camera app opens in
/// Nook, with the container's name, where it is and what's in it (F8). Print, Share or Save.
struct QRLabelSheet: View {
    let spot: Spot
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var labelSize = LabelSize.shipping
    @State private var listsItems = true
    @State private var toast: ToastMessage?
    @State private var printer = LabelPrinter()
    @Environment(\.dynamicTypeSize) private var typeSize

    private var label: BoxLabel {
        let names = ItemService(context: context).items(in: spot).map(\.name).sorted()
        return BoxLabel(name: spot.name, place: spot.room.map { Location(room: $0, spot: spot.parent).path } ?? "",
                        items: listsItems ? names : [], qrCode: QRCode.image(for: DeepLink.spot(spot.qrID).url),
                        size: labelSize)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    preview
                    VStack(alignment: .leading, spacing: NookSpace.s1) {
                        Text("Label size").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                        Picker("Label size", selection: $labelSize) {
                            ForEach(LabelSize.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .nookHaptic(.selected, trigger: labelSize)
                    }
                    Toggle("List top items", isOn: $listsItems)
                        .font(.nookBody)
                        .padding(.horizontal, NookSpace.s2)
                        .frame(minHeight: NookLayout.rowHeight)
                        .nookCard(radius: NookRadius.medium, elevation: .flat)
                    actions
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(NookColor.canvas)
            .navigationTitle("Box Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .toast($toast)
        }
    }

    /// The label at a size that fits the sheet, on paper.
    private var preview: some View {
        let label = label
        return ViewThatFits(in: .horizontal) {
            label.scaleEffect(1.25).frame(width: label.size.size.width * 1.25, height: label.size.size.height * 1.25)
            label
        }
        .warmShadow(.lifted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, NookSpace.s2)
        // A picture of the label: one image element, not its paper-sized text.
        .accessibilityHidden(true)
        .overlay {
            Color.clear.accessibilityElement()
                .accessibilityLabel(Text("Label preview: \(spot.name), with a code that opens it in Nook"))
                .accessibilityAddTraits(.isImage)
        }
    }

    private var actions: some View {
        VStack(spacing: NookSpace.s1) {
            Button { printer.print(label) } label: {
                Label("Print", systemImage: "printer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
            // Side by side, as on the board; stacked at accessibility sizes so the words fit.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: NookSpace.s1)) : AnyLayout(HStackLayout(spacing: NookSpace.s1))
            layout { share; save }
        }
    }

    private var share: some View {
        let image = Image(uiImage: label.image())
        return ShareLink(item: image, preview: SharePreview(Text(spot.name), image: image)) {
            Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
        }
        .buttonStyle(.nookSecondary)
    }

    private var save: some View {
        Button(action: saveImage) {
            Label("Save Image", systemImage: "photo.badge.arrow.down").frame(maxWidth: .infinity)
        }
        .buttonStyle(.nookSecondary)
    }

    /// Add-only Photos access, asked the first time (01 §13, D56).
    private func saveImage() {
        let image = label.image()
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
                toast = ToastMessage(symbol: "photo", "Saved to Photos.")
            } catch {
                toast = ToastMessage(symbol: "exclamationmark.triangle", "Nook can’t save to Photos. You can turn it on in Settings.")
            }
        }
    }
}

/// A printed label: always the light paper colors and a fixed text size, like the report.
struct BoxLabel: View {
    let name: String
    let place: String
    let items: [String]
    let qrCode: CGImage?
    let size: LabelSize

    private var small: Bool { size == .address }

    var body: some View {
        let layout = size == .card ? AnyLayout(VStackLayout(spacing: NookSpace.s2)) : AnyLayout(HStackLayout(spacing: NookSpace.s1))
        layout {
            Group {
                if let qrCode {
                    Image(decorative: qrCode, scale: 1).interpolation(.none).resizable().scaledToFit()
                }
            }
            .frame(maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            VStack(alignment: size == .card ? .center : .leading, spacing: NookSpace.half) {
                Text(name).font(small ? .nookCaption.weight(.semibold) : .nookSection).lineLimit(2)
                    .foregroundStyle(NookColor.textPrimary)
                if !place.isEmpty {
                    Text(place).font(small ? .nookCaption : .nookFootnote).lineLimit(1).foregroundStyle(NookColor.textSecondary)
                }
                if !items.isEmpty, !small {
                    Text(itemsLine).font(.nookFootnote).lineLimit(size == .card ? 4 : 2).foregroundStyle(NookColor.textSecondary)
                }
            }
            .multilineTextAlignment(size == .card ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: size == .card ? .center : .leading)
        }
        .padding(small ? NookSpace.half : NookSpace.s1)
        .frame(width: size.size.width, height: size.size.height)
        .background(NookColor.surfaceRaised, in: .rect(cornerRadius: NookRadius.small))
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .small)
    }

    /// "Measuring cups, hand mixer, cookie cutters, +4 more".
    private var itemsLine: String {
        let shown = items.prefix(3).joined(separator: ", ")
        return items.count > 3 ? String(localized: "\(shown), +\(items.count - 3) more") : shown
    }

    /// The label at print resolution (3×), for sharing, saving and printing.
    @MainActor func image() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

enum QRCode {
    /// A crisp QR code: one pixel a module, scaled with `.interpolation(.none)`. Medium error
    /// correction survives a scuffed box.
    static func image(for url: URL) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}

/// AirPrint at the label's real size, top left of the paper: right on a label printer's
/// roll and in the first spot of a label sheet.
@MainActor
final class LabelPrinter {
    private var chooser: PaperChooser?   // the controller holds its delegate weakly

    func print(_ label: BoxLabel) {
        let size = label.size.size
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = label.name
        controller.printInfo = info
        chooser = PaperChooser(size: size)
        controller.delegate = chooser
        controller.printPageRenderer = LabelPageRenderer(image: label.image(), size: size)
        controller.present(animated: true)
    }
}

private nonisolated final class PaperChooser: NSObject, UIPrintInteractionControllerDelegate {
    let size: CGSize

    init(size: CGSize) { self.size = size }

    func printInteractionController(_ controller: UIPrintInteractionController,
                                    choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
        UIPrintPaper.bestPaper(forPageSize: size, withPapersFrom: paperList)
    }
}

private nonisolated final class LabelPageRenderer: UIPrintPageRenderer {
    let image: UIImage
    let size: CGSize

    init(image: UIImage, size: CGSize) {
        (self.image, self.size) = (image, size)
    }

    override var numberOfPages: Int { 1 }

    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        image.draw(in: CGRect(origin: printableRect.origin, size: size))
    }
}
