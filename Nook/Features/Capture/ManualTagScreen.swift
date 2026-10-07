import SwiftUI
import SwiftData
import NookKit
import NookUI

/// One thing tagged on a room-scan photo (C-04). `box` is normalized with a top-left origin;
/// nil means the whole photo ("Add Item by Name", for VoiceOver and Voice Control).
struct ManualTag: Identifiable, Equatable {
    let id = UUID()
    var photo: Int
    var box: CGRect?
    var name: String
    var category: String
    var isAccepted = true   // the user named it, so it's in until they say otherwise
}

/// C-04's state: the photos, the tags, and the one being named. Survives the window
/// changing size mid-tagging, because the screen owns it.
@Observable @MainActor
final class ManualTagModel {
    struct Naming: Equatable {
        var photo: Int
        var box: CGRect?
    }

    let photos: [ScanPhoto]
    var current = 0
    var tags: [ManualTag] = []
    var naming: Naming?
    var name = ""
    var selected: ManualTag.ID?
    private(set) var images: [String: CGImage] = [:]

    /// Crops are padded so a tight box still shows the whole thing (D48).
    static let cropPadding = 0.08
    /// A tap places a square this share of the photo's short side (C-04).
    static let tapBoxShare = 0.25

    init(photos: [ScanPhoto]) { self.photos = photos }

    var acceptedCount: Int { tags.filter(\.isAccepted).count }
    var currentTags: [ManualTag] { tags.filter { $0.photo == current && $0.box != nil } }

    func load(_ index: Int) async {
        let fileName = photos[index].fileName
        guard images[fileName] == nil else { return }
        images[fileName] = await BlobStore.shared.image(fileName, maxPixels: BlobStore.photoPixels)
    }

    /// A tap: a square around the point, kept inside the photo.
    func boxForTap(at point: CGPoint) -> CGRect {
        let photo = photos[current]
        let side = Self.tapBoxShare * Double(min(photo.width, photo.height))
        let size = CGSize(width: side / Double(max(photo.width, 1)), height: side / Double(max(photo.height, 1)))
        let x = min(max(point.x - size.width / 2, 0), 1 - size.width)
        let y = min(max(point.y - size.height / 2, 0), 1 - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    func startNaming(_ box: CGRect?) {
        naming = Naming(photo: current, box: box)
        name = ""
        selected = nil
    }

    /// Return or Add: the named box becomes a card.
    @discardableResult
    func addTag(category: (String) -> String?) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let naming, !trimmed.isEmpty else { return false }
        let tag = ManualTag(photo: naming.photo, box: naming.box, name: trimmed, category: category(trimmed) ?? "")
        tags.append(tag)
        selected = tag.id
        self.naming = nil
        name = ""
        return true
    }

    func select(_ tag: ManualTag) {
        selected = tag.id
        current = tag.photo
    }

    func remove(_ tag: ManualTag) {
        tags.removeAll { $0.id == tag.id }
        if selected == tag.id { selected = nil }
    }

    func acceptAll() {
        for index in tags.indices { tags[index].isAccepted = true }
    }

    /// The padded crop for a tag, and the normalized rect it came from.
    func crop(_ tag: ManualTag) -> (image: CGImage, rect: CGRect)? {
        guard let image = images[photos[tag.photo].fileName] else { return nil }
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let rect = (tag.box ?? unit)
            .insetBy(dx: -(tag.box?.width ?? 0) * Self.cropPadding, dy: -(tag.box?.height ?? 0) * Self.cropPadding)
            .intersection(unit)
        let pixels = CGRect(x: rect.minX * Double(image.width), y: rect.minY * Double(image.height),
                            width: rect.width * Double(image.width), height: rect.height * Double(image.height)).integral
        guard let cropped = image.cropping(to: pixels) else { return nil }
        return (cropped, rect)
    }

    /// A draft for one tag, its crop already on disk (D40).
    func draft(for tag: ManualTag, at location: Location?) async -> ItemDraft? {
        await load(tag.photo)
        guard let (image, rect) = crop(tag), let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.9),
              let photo = await ScanPhoto.save(data) else { return nil }
        var draft = ItemDraft(currencyCode: HomeCurrency.code, location: location)
        draft.name = tag.name
        draft.category = tag.category
        draft.photos = [.init(fileName: photo.fileName, width: photo.width, height: photo.height,
                              box: .init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))]
        return draft
    }

    /// Save all: each accepted card becomes an item, placed through LocationService (D38).
    func saveAll(context: ModelContext, location: Location?) async throws -> [Item] {
        var drafts: [ItemDraft] = []
        for tag in tags where tag.isAccepted {
            if let draft = await draft(for: tag, at: location) { drafts.append(draft) }
        }
        let service = ItemService(context: context)
        let items = try drafts.map { try service.create($0) }
        try context.save()
        return items
    }
}

/// C-04 Manual tagging, Classic path (01 C-04, D48). Tap or draw a box, name it with
/// suggestions, and each tag becomes a card with Accept, Edit and Remove; Save all saves
/// them to the chosen place. Compact: the photo above the cards. Regular: the photo left,
/// cards right. Accessibility sizes: one scrolling column with cards as a list.
struct ManualTagScreen: View {
    @Binding var location: Location?
    /// The saved items, or nil when nothing was saved.
    let finish: ([Item]?) -> Void

    @State private var model: ManualTagModel
    @State private var editing: EditStart?
    @State private var edited: [Item] = []
    @State private var choosesPlace = false
    @State private var confirmsDiscard = false
    @State private var isSaving = false
    @State private var failure = false
    @State private var suggestions: [String] = []
    @FocusState private var nameFocused: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.windowSizeClass) private var windowSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct EditStart: Identifiable {
        let id = UUID()
        let tag: ManualTag
        let draft: ItemDraft
    }

    init(photos: [ScanPhoto], location: Binding<Location?>, finish: @escaping ([Item]?) -> Void) {
        _model = State(initialValue: ManualTagModel(photos: photos))
        _location = location
        self.finish = finish
    }

    var body: some View {
        NavigationStack {
            layout
                .background(NookColor.canvas)
                .navigationTitle(model.photos.count > 1
                                 ? Text("Photo \(model.current + 1) of \(model.photos.count)") : Text("Tag Items"))
                .toolbarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .safeAreaInset(edge: .bottom) { saveBar }
        }
        .task(id: model.current) { await model.load(model.current) }
        .sheet(isPresented: $choosesPlace) {
            MovePicker(title: Text("Where are these?"), current: location, allowsNoRoom: true) { location = $0 }
        }
        .sheet(item: $editing) { start in
            ItemEditor(draft: start.draft) { item in
                // Edited in I-02 and saved there; its card is done.
                edited.append(item)
                model.remove(start.tag)
            }
        }
        .confirmationDialog(Text("Discard ^[\(model.tags.count) tagged item](inflect: true)?"),
                            isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { finish(edited.isEmpty ? nil : edited) }
            Button("Keep Tagging", role: .cancel) {}
        }
        .alert(Text("Couldn’t save right now. Your photos are still here."), isPresented: $failure) {
            Button("OK") {}
        }
    }

    // MARK: Layout

    @ViewBuilder
    private var layout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            cardsScroll {
                VStack(alignment: .leading, spacing: NookSpace.s2) {
                    photoPane.frame(height: NookLayout.heroPhotoHeight)
                    cardsContent
                }
                .padding(NookSpace.s2)
            }
        } else if windowSizeClass == .regular {
            HStack(spacing: 0) {
                photoPane.padding(NookSpace.s2)
                Divider()
                cardsScroll { cardsContent.padding(NookSpace.s2) }
                    .frame(width: NookLayout.itemColumnWidth)
            }
        } else {
            VStack(spacing: 0) {
                photoPane
                    .padding([.horizontal, .top], NookSpace.s2)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.45 }
                cardsScroll { cardsContent.padding(NookSpace.s2) }
            }
        }
    }

    /// Keeps the name field, then each new card, in view: on a small phone they sit below
    /// the photo.
    private func cardsScroll(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ScrollViewReader { proxy in
            ScrollView { content }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.naming) { _, naming in
                    guard naming != nil else { return }
                    withNookAnimation(.settle, reduceMotion: reduceMotion) { proxy.scrollTo(Self.namingID, anchor: .bottom) }
                }
                .onChange(of: model.tags.count) { old, new in
                    guard new > old, let last = model.tags.last else { return }
                    withNookAnimation(.settle, reduceMotion: reduceMotion) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
        }
    }

    private static let namingID = "naming"

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", role: .cancel) { model.tags.isEmpty ? finish(edited.isEmpty ? nil : edited) : (confirmsDiscard = true) }
        }
        if model.photos.count > 1 {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Previous Photo", systemImage: "chevron.left") { model.current -= 1 }
                    .disabled(model.current == 0)
                Button("Next Photo", systemImage: "chevron.right") { model.current += 1 }
                    .disabled(model.current == model.photos.count - 1)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Accept All") { model.acceptAll() }   // D28: in the header, like C-03
                .disabled(model.tags.allSatisfy(\.isAccepted))
        }
    }

    private var saveBar: some View {
        Button(action: saveAll) {
            Text("Save ^[\(model.acceptedCount) Item](inflect: true)").frame(maxWidth: .infinity)
        }
        .buttonStyle(NookButtonStyle(.primary, isLoading: isSaving))
        .disabled(model.acceptedCount == 0 || isSaving)
        .padding(NookSpace.s2)
        .frame(maxWidth: NookLayout.readableWidth)
        .frame(maxWidth: .infinity)
        .background(NookColor.canvas)
    }

    // MARK: Photo, boxes and gestures

    private var photoPane: some View {
        GeometryReader { proxy in
            let photo = model.photos[model.current]
            let fitted = Self.fit(CGSize(width: photo.width, height: photo.height), in: proxy.size)
            ZStack(alignment: .topLeading) {
                if let image = model.images[photo.fileName] {
                    Image(decorative: image, scale: 1).resizable()
                        .frame(width: fitted.width, height: fitted.height)
                } else {
                    NookColor.surfaceSunken.frame(width: fitted.width, height: fitted.height)
                }
                PhotoTagLayer(model: model, size: fitted.size)
                    .frame(width: fitted.width, height: fitted.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
            .offset(x: fitted.minX, y: fitted.minY)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Photo \(model.current + 1)"))
    }

    /// The photo's rect, aspect-fit and centered in `space`.
    static func fit(_ size: CGSize, in space: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: space) }
        let scale = min(space.width / size.width, space.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: (space.width - fitted.width) / 2, y: (space.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }

    // MARK: Naming and cards

    private var cardsContent: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Button { choosesPlace = true } label: {
                HStack(spacing: NookSpace.s1) {
                    Image(systemName: "mappin.and.ellipse").accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Saving to").font(.nookCaption).foregroundStyle(NookColor.textSecondary)
                        Text(verbatim: location?.path ?? String(localized: "Choose a room"))
                            .font(.nookMeta.weight(.semibold))
                            .foregroundStyle(NookColor.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(NookColor.textSecondary).accessibilityHidden(true)
                }
                .frame(minHeight: NookLayout.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Saving to"))
            .accessibilityValue(Text(verbatim: location?.names.joined(separator: ", ") ?? String(localized: "Choose a room")))

            if model.naming != nil {
                namingPanel.id(Self.namingID)
            } else {
                Text("Tap an item, or draw a box around it.")
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                Button { model.startNaming(nil); nameFocused = true } label: {
                    Label("Add Item by Name", systemImage: "text.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookSecondary)
            }

            if !model.tags.isEmpty {
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Text("^[\(model.tags.count) item](inflect: true) tagged")
                        .font(.nookSection)
                        .foregroundStyle(NookColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Tag as many as you like, then save.")
                        .font(.nookMeta)
                        .foregroundStyle(NookColor.textSecondary)
                }
                ForEach(model.tags) { tag in
                    TagCard(tag: tag, crop: model.crop(tag)?.image, isSelected: model.selected == tag.id,
                            select: { model.select(tag) },
                            toggleAccept: { if let index = model.tags.firstIndex(of: tag) { model.tags[index].isAccepted.toggle() } },
                            edit: { edit(tag) },
                            remove: { withNookAnimation(.settle, reduceMotion: reduceMotion) { model.remove(tag) } })
                        .id(tag.id)
                }
            }
        }
        .frame(maxWidth: NookLayout.readableWidth, alignment: .leading)
    }

    private var namingPanel: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            HStack(alignment: .bottom, spacing: NookSpace.s1) {
                NookTextField(Text("What is it?"), text: $model.name, prompt: Text("Kettle"))
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(.nookPrimary)
                    .fixedSize()
                    .disabled(model.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: NookSpace.s1) {
                        ForEach(suggestions, id: \.self) { name in
                            FilterChip(verbatim: name, isSelected: false) { model.name = name; add() }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Name suggestions"))
            }
            Button("Cancel") { model.naming = nil; nameFocused = false }
                .buttonStyle(.nookTertiary)
        }
        .padding(NookSpace.s2)
        .nookCard(elevation: .flat)
        .onAppear { nameFocused = true }
        // D35: suggestions follow the name after a pause, never rewriting the field.
        .task(id: model.name) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let past = (try? ItemService(context: context).pastValues(\.name)) ?? []
            suggestions = ItemSuggestions.suggestions(for: model.name, past: past, common: CommonItems.all)
        }
    }

    private func add() {
        if model.addTag(category: { ItemSuggestions.category(for: $0, in: CommonItems.all) }) {
            nameFocused = false
        }
    }

    private func edit(_ tag: ManualTag) {
        Task {
            guard let draft = await model.draft(for: tag, at: location) else { return }
            editing = EditStart(tag: tag, draft: draft)
        }
    }

    private func saveAll() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let items = try await model.saveAll(context: context, location: location)
                finish(edited + items)
            } catch {
                context.rollback()
                failure = true
            }
        }
    }
}

/// The boxes on the photo, the box being named, and the gesture that makes new ones:
/// a tap places a square, a drag draws a box.
private struct PhotoTagLayer: View {
    let model: ManualTagModel
    let size: CGSize
    @State private var drawing: CGRect?

    var body: some View {
        let tags = model.currentTags
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    guard value.translation.width.magnitude + value.translation.height.magnitude > NookSpace.s1 else { return }
                    drawing = normalized(from: value.startLocation, to: value.location)
                }.onEnded { value in
                    if let box = drawing, box.width > 0.03, box.height > 0.03 {
                        model.startNaming(box)
                    } else {
                        model.startNaming(model.boxForTap(at: CGPoint(x: value.location.x / size.width,
                                                                      y: value.location.y / size.height)))
                    }
                    drawing = nil
                })
                .accessibilityHidden(true)   // "Add Item by Name" does the same without drawing
            DetectionOverlay(boxes: tags.compactMap(\.box), names: tags.map(\.name),
                             selected: tags.firstIndex { $0.id == model.selected }) { model.select(tags[$0]) }
            if let box = drawing ?? (model.naming?.photo == model.current ? model.naming?.box : nil) {
                DetectionOutline(isSelected: true, drawsOn: false)
                    .frame(width: box.width * size.width, height: box.height * size.height)
                    .offset(x: box.minX * size.width, y: box.minY * size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func normalized(from start: CGPoint, to end: CGPoint) -> CGRect {
        let rect = CGRect(x: min(start.x, end.x) / size.width, y: min(start.y, end.y) / size.height,
                          width: abs(end.x - start.x) / size.width, height: abs(end.y - start.y) / size.height)
        return rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

/// A tagged item's card: its crop, name and category, with Accept, Edit and Remove (C-03's
/// controls, so both paths look alike). One VoiceOver element with custom actions.
private struct TagCard: View {
    let tag: ManualTag
    let crop: CGImage?
    let isSelected: Bool
    let select: () -> Void
    let toggleAccept: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    @Environment(\.nookAccent) private var accent

    var body: some View {
        HStack(spacing: NookSpace.s2) {
            Button(action: select) {
                HStack(spacing: NookSpace.s2) {
                    Group {
                        if let crop { Image(decorative: crop, scale: 1).resizable().scaledToFill() } else { NookColor.surfaceSunken }
                    }
                    .frame(width: NookLayout.rowThumbnailSize, height: NookLayout.rowThumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                    VStack(alignment: .leading, spacing: NookSpace.half) {
                        Text(verbatim: tag.name).font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
                        if !tag.category.isEmpty {
                            Text(verbatim: tag.category).font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: toggleAccept) {
                Image(systemName: tag.isAccepted ? "checkmark.circle.fill" : "circle")
                    .font(.nookTitle)
                    .foregroundStyle(tag.isAccepted ? accent.color : NookColor.textSecondary)
                    .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
            }
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            Menu {
                Button("Edit", systemImage: "pencil", action: edit)
                Button("Remove", systemImage: "trash", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.nookTitle)
                    .foregroundStyle(NookColor.textSecondary)
                    .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .padding(NookSpace.s1)
        .nookCard(elevation: .flat)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: NookRadius.card, style: .continuous)
                    .strokeBorder(accent.color, lineWidth: NookLayout.outlineWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [tag.name, tag.category].filter { !$0.isEmpty }.joined(separator: ", ")))
        .accessibilityValue(tag.isAccepted ? Text("Accepted") : Text("Not accepted"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: tag.isAccepted ? Text("Don’t Accept") : Text("Accept"), toggleAccept)
        .accessibilityAction(named: Text("Edit"), edit)
        .accessibilityAction(named: Text("Remove"), remove)
        .accessibilityAction(.default, select)
    }
}
