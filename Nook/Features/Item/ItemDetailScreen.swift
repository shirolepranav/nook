import SwiftUI
import SwiftData
import QuickLook
import NookKit
import NookUI

/// I-01 Item detail: the photos, then where it is, then the facts. Content is paper; glass
/// stays on the toolbar (03 §1.6). On a wide window the items around it sit in a column
/// beside it (iPadItem board). Lend joins in P7, warranty in P7 (D39), and the Private lock
/// in P12.
struct ItemDetailScreen: View {
    let item: Item
    @State private var shown: Item?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context

    var body: some View {
        let current = shown ?? item
        let siblings = siblingItems
        if sizeClass == .regular, siblings.count > 1 {
            HStack(alignment: .top, spacing: 0) {
                SiblingColumn(items: siblings, selected: current) { shown = $0 }
                    .frame(width: NookLayout.itemColumnWidth)
                Divider()
                ItemDetail(item: current).id(current.id)
            }
            .background(NookColor.canvas)
        } else {
            ItemDetail(item: current)
        }
    }

    /// The items sharing this one's spot, or loose in its room.
    private var siblingItems: [Item] {
        let service = ItemService(context: context)
        if let spot = item.spot { return service.items(in: spot) }
        if let room = item.room { return service.looseItems(in: room) }
        return []
    }
}

private struct SiblingColumn: View {
    let items: [Item]
    let selected: Item
    let select: (Item) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: NookSpace.s1) {
                ForEach(items) { item in
                    Button { select(item) } label: {
                        StoredImage(fileName: item.cover?.fileName) { image in
                            ItemRow(name: item.name, detail: item.placeText, photo: image)
                                .padding(.horizontal, NookSpace.s1)
                                .background(item.id == selected.id ? NookColor.surfaceSunken : .clear,
                                            in: RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item.id == selected.id ? .isSelected : [])
                }
            }
            .padding(NookSpace.s2)
        }
    }
}

private struct ItemDetail: View {
    let item: Item
    @State private var editing = false
    @State private var viewingPhoto: Int?
    @State private var receiptURL: URL?
    @State private var confirmsDelete = false
    @State private var toast: ToastMessage?
    @State private var addsReceipt = false
    @State private var moving: LocationEvent.Source?
    @State private var moves = 0   // plays the success haptic (03 §10)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.dismiss) private var dismiss

    private var actions: ItemActions { ItemActions(context: context, undoManager: undoManager) }
    private var hasPhotos: Bool { !(item.photos ?? []).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                hero
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    titleBlock
                    locationCard
                    detailsCard
                    receiptCard
                    if !item.notes.isEmpty { notesCard }
                    historyRow
                }
                .padding(.horizontal, NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
        .ignoresSafeArea(edges: hasPhotos ? .top : [])   // the hero runs under the glass bar
        .background(NookColor.canvas)
        .captureButton(at: Location(of: item))   // D32: item screens show Capture
        .navigationTitle(Text(verbatim: item.name))
        .toolbar(removing: .title)   // the mockup shows only the back button over the hero
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
            ToolbarItem(placement: .primaryAction) {
                if let cover = item.cover {
                    ShareLink(item: BlobStore.shared.url(for: cover.fileName, in: .photos),
                              message: Text(verbatim: item.shareText))
                } else {
                    ShareLink(item: item.shareText)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(item.isPrivate ? "Mark Not Private" : "Mark Private",
                       systemImage: item.isPrivate ? "lock.open" : "lock") {
                    toast = actions.setPrivate([item], !item.isPrivate)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Duplicate", systemImage: "plus.square.on.square") { toast = actions.duplicate(item) }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
            }
        }
        .focusedSceneValue(\.itemCommands, ItemCommands(edit: { editing = true }, move: { moving = .manual },
                                                         delete: { confirmsDelete = true }))
        .confirmationDialog(Text("Delete \(item.name)?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("You can restore it from Recently Deleted for 30 days.")
        }
        .sheet(isPresented: $editing) { ItemEditor(item: item) }
        .fullScreenCover(item: Binding { viewingPhoto.map(PhotoIndex.init) } set: { viewingPhoto = $0?.index }) {
            PhotoViewer(item: item, start: $0.index)
        }
        .quickLookPreview($receiptURL)   // D42: Quick Look handles images and long PDFs
        .sheet(isPresented: $addsReceipt) { ItemEditor(item: item) }
        .sheet(item: $moving) { source in
            MovePicker(title: source == .found ? Text("Where did you find it?") : Text("Move \(item.name)"),
                       current: Location(of: item)) { place in
                guard let place else { return }
                withNookAnimation(.settle, reduceMotion: reduceMotion) {
                    if let message = actions.move([item], to: place, source: source) {
                        toast = message
                        moves += 1
                    }
                }
            }
        }
        .nookHaptic(.saved, trigger: moves)
        .toast($toast)
    }

    private func delete() {
        let message = actions.delete([item])
        dismiss()
        toast = message   // shown if this screen stays, e.g. beside the column on iPad
    }

    // MARK: Hero

    private var hero: some View {
        let photos = item.orderedPhotos
        return Group {
            if photos.isEmpty {
                NookPhotoPlaceholder()
            } else {
                TabView {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        Button { viewingPhoto = index } label: {
                            StoredImage(fileName: photo.fileName, maxPixels: 1200) { image in
                                ZStack {
                                    NookColor.surfaceSunken
                                    image?.resizable().scaledToFill()
                                }
                                .clipped()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Photo \(index + 1) of \(photos.count). Open photo viewer"))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            }
        }
        .frame(height: NookLayout.heroPhotoHeight)
        .frame(maxWidth: .infinity)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: NookRadius.hero, bottomTrailingRadius: NookRadius.hero,
                                          style: .continuous))
        .accessibilityIgnoresInvertColors()
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            if item.isPrivate {
                StatusPill(.privateItem, Text("Private"))
            }
            Text(verbatim: item.name)
                .font(.nookDisplay)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // Side by side, or stacked at accessibility sizes so neither word breaks.
            let row = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            row {
                if !item.category.isEmpty {
                    Text(verbatim: item.category).font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                if let value = item.value {
                    MoneyText(value.amount, currencyCode: value.currencyCode, font: .nookTitle)
                        .foregroundStyle(NookColor.textPrimary)
                }
            }
            if !item.tags.isEmpty {
                NookFlowLayout(spacing: NookSpace.s1) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(verbatim: tag)
                            .font(.nookMeta)
                            .foregroundStyle(NookColor.textPrimary)
                            .padding(.horizontal, NookSpace.s2)
                            .frame(minHeight: NookLayout.minTapTarget)
                            .background(NookColor.surface, in: Capsule())
                            .overlay { Capsule().strokeBorder(NookColor.hairline, lineWidth: 1) }
                            .accessibilityLabel(Text("Tag: \(tag)"))
                    }
                }
                // One element per tag: an element combined over the flow layout had no frame
                // on the text, and the audit flagged the tags as inaccessible text (D47).
            }
        }
    }

    // MARK: Where it is (the most prominent card, 01 I-01)

    private var locationCard: some View {
        let location = Location(of: item)
        let color = location.flatMap { RoomColor(rawValue: $0.room.colorKey) } ?? .stone
        return VStack(alignment: .leading, spacing: NookSpace.s2) {
            place(location)
            // Side by side, stacked at accessibility sizes (03 §8.2: labels wrap, never truncate).
            let buttons = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: NookSpace.s1)) : AnyLayout(HStackLayout(spacing: NookSpace.s1))
            buttons {
                Button("Move") { moving = .manual }
                    .buttonStyle(.nookSecondary)
                Button(location == nil ? "Choose a Room" : "Found It Here Instead") {
                    moving = location == nil ? .manual : .found
                }
                .buttonStyle(.nookTertiary)
            }
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.fill, in: RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous))
    }

    /// Where it is and how fresh that is (01 §1.2).
    private func place(_ location: Location?) -> some View {
        HStack(alignment: .top, spacing: NookSpace.s2) {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text(verbatim: location?.path ?? String(localized: "No room yet"))
                    .font(.nookSection)
                    .foregroundStyle(NookColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: location?.names.joined(separator: ", ")
                                             ?? String(localized: "No room yet")))
                Text("Last confirmed \(item.lastConfirmedAt, format: .dateTime.month(.abbreviated).day())")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            Spacer(minLength: 0)
            if let spotPhoto = item.spot?.photo {
                StoredImage(fileName: spotPhoto.fileName) { image in
                    NookPhotoThumb(image: image)
                }
                .accessibilityLabel(Text("Spot photo: \(item.spot?.name ?? "")"))
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: History

    /// "Location history · 4 moves" → I-05. Hidden until there's something to show.
    @ViewBuilder
    private var historyRow: some View {
        let count = item.events?.count ?? 0
        if count > 0 {
            NavigationLink {
                LocationHistoryScreen(item: item)
            } label: {
                HStack {
                    Text("Location history")
                        .font(.nookBody)
                        .foregroundStyle(NookColor.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(count) places")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, NookSpace.s2)
                .frame(minHeight: NookLayout.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .nookCard(elevation: .flat)
        }
    }

    // MARK: Details

    @ViewBuilder
    private var detailsCard: some View {
        let rows = detailRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                    if index < rows.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, NookSpace.s2)
            .nookCard(elevation: .flat)
        }
    }

    private var detailRows: [AnyView] {
        var rows: [AnyView] = []
        if !item.brand.isEmpty { rows.append(AnyView(DetailRow(Text("Brand"), Text(verbatim: item.brand)))) }
        if !item.model.isEmpty { rows.append(AnyView(DetailRow(Text("Model"), Text(verbatim: item.model)))) }
        if !item.serial.isEmpty { rows.append(AnyView(serialRow)) }
        if item.quantity > 1 {
            rows.append(AnyView(DetailRow(Text("Quantity"), Text(item.quantity, format: .number))))
        }
        if let date = item.purchaseDate {
            let when = Text(date, format: .dateTime.month(.abbreviated).day().year())
            let value = item.store.isEmpty ? when : Text("\(when) · \(item.store)")
            rows.append(AnyView(DetailRow(Text("Purchased"), value)))
        } else if !item.store.isEmpty {
            rows.append(AnyView(DetailRow(Text("Store"), Text(verbatim: item.store))))
        }
        if let value = item.value {
            rows.append(AnyView(DetailRow(Text("Price")) {
                MoneyText(value.amount, currencyCode: value.currencyCode, font: .nookBody)
            }))
        }
        if !item.barcode.isEmpty {
            rows.append(AnyView(DetailRow(Text("Barcode"), Text(verbatim: item.barcode))))
        }
        return rows
    }

    /// Middle-truncated, tap to copy (01 §15).
    private var serialRow: some View {
        Button {
            UIPasteboard.general.string = item.serial
            toast = ToastMessage(symbol: "doc.on.doc", "Serial copied.")
        } label: {
            DetailRow(Text("Serial")) {
                HStack(spacing: NookSpace.half) {
                    Text(verbatim: item.serial)
                        .font(.nookBody.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "doc.on.doc").font(.nookFootnote).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Serial \(item.serial)"))
        .accessibilityHint(Text("Copies it"))
    }

    // MARK: Receipt and notes

    private var receiptCard: some View {
        Group {
            if let receipt = item.receipts?.first {
                Button {
                    receiptURL = BlobStore.shared.url(for: receipt.fileName, in: .receipts)
                } label: {
                    HStack(spacing: NookSpace.s2) {
                        StoredImage(fileName: receipt.fileName) { NookPhotoThumb(image: $0) }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: item.store.isEmpty ? String(localized: "Receipt") : item.store)
                                .font(.nookHeadline)
                                .foregroundStyle(NookColor.textPrimary)
                            Text(receipt.kind == .pdf ? "PDF" : "Photo")
                                .font(.nookMeta)
                                .foregroundStyle(NookColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .font(.nookFootnote)
                            .foregroundStyle(NookColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(NookSpace.s2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("Opens the receipt"))
            } else {
                Button { addsReceipt = true } label: {
                    Label("Add Receipt", systemImage: "receipt")
                        .frame(maxWidth: .infinity, minHeight: NookLayout.rowHeight, alignment: .leading)
                        .padding(.horizontal, NookSpace.s2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .nookCard(elevation: .flat)
        .hoverEffect(.highlight)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.half) {
            Text("Notes").font(.nookFootnote.weight(.semibold)).foregroundStyle(NookColor.textSecondary)
            Text(verbatim: item.notes).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard(elevation: .flat)
        .accessibilityElement(children: .combine)
    }
}

private struct PhotoIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// A label and value in the details card (I-01): label in meta, value in body.
private struct DetailRow<Value: View>: View {
    let label: Text
    let value: Value
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ label: Text, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: NookSpace.s2))
        layout {
            label.font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            value.font(.nookBody).foregroundStyle(NookColor.textPrimary)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .frame(minHeight: NookLayout.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

extension DetailRow where Value == Text {
    init(_ label: Text, _ value: Text) {
        self.init(label) { value }
    }
}

/// A square list thumbnail (03 §5: medium radius).
struct NookPhotoThumb: View {
    let image: Image?

    var body: some View {
        ZStack {
            NookColor.surfaceSunken
            if let image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(NookColor.textTertiary)
            }
        }
        .frame(width: NookLayout.rowThumbnailSize, height: NookLayout.rowThumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
        .accessibilityIgnoresInvertColors()
    }
}

/// The hero with no photos yet.
private struct NookPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            NookColor.surfaceSunken
            Image(systemName: "photo").font(.nookDisplay).foregroundStyle(NookColor.textTertiary)
        }
        .accessibilityHidden(true)
    }
}

extension Item {
    /// What Share sends with the cover photo: the name and where it is.
    var shareText: String {
        [name, Location(of: self)?.path].compactMap { $0 }.joined(separator: "\n")
    }
}
