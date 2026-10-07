import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import NookKit
import NookUI

/// I-02 Item editor, for a new item or an existing one. Only the name is required, so a
/// photo and a name save in 2 taps (F2). Photos and receipts go to disk as they're picked
/// (D40); the item itself is written only on Save. Warranty joins in P7 (D39).
struct ItemEditor: View {
    let item: Item?
    var cameraOff = false
    var onSave: ((Item) -> Void)?

    @State private var draft: ItemDraft
    private let initial: ItemDraft
    @State private var priceText: String
    @State private var tagText = ""
    @State private var nameError = false
    @State private var suggestions: [String] = []
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var receiptSource: ReceiptSource?
    @State private var takesPhoto = false
    @State private var confirmsDiscard = false
    @State private var namesCategory = false
    @State private var newCategory = ""
    @State private var choosesPlace = false
    @State private var failure: LocalizedStringResource?
    @State private var saved = 0
    @State private var failed = 0
    @FocusState private var focus: Field?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Field { case name, price, tag }

    init(item: Item? = nil, draft: ItemDraft? = nil, cameraOff: Bool = false, onSave: ((Item) -> Void)? = nil) {
        self.item = item
        self.cameraOff = cameraOff
        self.onSave = onSave
        let start = draft ?? item.map(ItemDraft.init) ?? ItemDraft(currencyCode: HomeCurrency.code)
        initial = item.map(ItemDraft.init) ?? ItemDraft(currencyCode: start.currencyCode, location: start.location)
        _draft = State(initialValue: start)
        _priceText = State(initialValue: start.price.map { $0.formatted(.number.grouping(.never)) } ?? "")
    }

    private var service: ItemService { ItemService(context: context) }
    private var hasChanges: Bool { draft != initial || !priceText.isEmpty && draft.price == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    photoStrip
                    nameField
                    whereRow
                    detailsSection
                    purchaseSection
                    receiptSection
                    NookTextField(Text("Notes"), text: $draft.notes, prompt: Text("Anything worth remembering"))
                    privateToggle
                }
                .padding(NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(NookColor.canvas)
            .navigationTitle(item == nil ? "New Item" : "Edit Item")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { hasChanges ? (confirmsDiscard = true) : discard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .confirmationDialog(Text("Discard changes to this item?"), isPresented: $confirmsDiscard,
                                titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive, action: discard)
                Button("Keep Editing", role: .cancel) {}
            }
            .alert(Text("New category"), isPresented: $namesCategory) {
                TextField("Category", text: $newCategory)
                Button("Cancel", role: .cancel) {}
                Button("Add") { draft.category = newCategory.trimmingCharacters(in: .whitespaces) }
            }
            .alert(Text(failure ?? ""), isPresented: Binding { failure != nil } set: { if !$0 { failure = nil } }) {
                Button("OK") {}
            }
        }
        .presentationSizing(.form)   // a centered form sheet on regular width (D29)
        .interactiveDismissDisabled(hasChanges)   // a swipe down can't lose edits
        .nookHaptic(.saved, trigger: saved)
        .nookHaptic(.failed, trigger: failed)
        .fullScreenCover(isPresented: $takesPhoto) {
            SinglePhotoCamera(offersSkip: false) { data in
                if let data { add(photoData: [data]) }
                takesPhoto = false
            } cancel: {
                takesPhoto = false
            }
        }
        // C-06: every receipt goes through the review, so its text is searchable (F5) and its
        // numbers can be tapped into the fields.
        .receiptScan($receiptSource) { result in
            result.apply(to: &draft)
            if let price = draft.price { priceText = price.formatted(.number.grouping(.never)) }
        }
        .onChange(of: pickedPhotos) { _, items in
            guard !items.isEmpty else { return }
            pickedPhotos = []
            Task { add(photoData: await load(items)) }
        }
        .onAppear { if item == nil { focus = .name } }
    }

    // MARK: Photos (up to 10, D7)

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            ScrollView(.horizontal) {
                HStack(spacing: NookSpace.s1) {
                    if draft.photos.count < ItemService.maxPhotos {
                        Menu {
                            if !cameraOff && Camera.isUsable {
                                Button("Take Photo", systemImage: "camera") { takesPhoto = true }
                            }
                            PhotosPicker(selection: $pickedPhotos,
                                         maxSelectionCount: ItemService.maxPhotos - draft.photos.count,
                                         matching: .images) {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            AddPhotoTile()
                        }
                        .accessibilityLabel(Text("Add photo"))
                    }
                    ForEach(Array(draft.photos.enumerated()), id: \.element.fileName) { index, photo in
                        StoredImage(fileName: photo.fileName) { PhotoTile(photo: $0, isCover: index == 0) }
                            .contextMenu { photoActions(index) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("Photo \(index + 1)"))
                            .accessibilityValue(index == 0 ? Text("Cover") : Text(verbatim: ""))
                            .accessibilityActions { photoActions(index) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Photos, \(draft.photos.count) of \(ItemService.maxPhotos)"))
            if cameraOff {
                // C-05 with the camera turned off: Photos still works, no dead end (D15).
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Label("Camera is off. Turn it on in Settings.", systemImage: "camera.badge.ellipsis")
                        .font(.nookFootnote)
                }
                .buttonStyle(.nookTertiary)
            }
        }
    }

    @ViewBuilder
    private func photoActions(_ index: Int) -> some View {
        if index > 0 {
            Button("Set as Cover", systemImage: "star") { draft.photos.insert(draft.photos.remove(at: index), at: 0) }
            Button("Move Left", systemImage: "arrow.left") { draft.photos.swapAt(index, index - 1) }
        }
        if index < draft.photos.count - 1 {
            Button("Move Right", systemImage: "arrow.right") { draft.photos.swapAt(index, index + 1) }
        }
        Button("Delete Photo", systemImage: "trash", role: .destructive) { draft.photos.remove(at: index) }
    }

    // MARK: Name, with suggestions (PRD §5)

    private var nameField: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            NookTextField(Text("Name"), text: $draft.name, prompt: Text("Espresso machine"),
                          error: nameError ? Text("Give it a name.") : nil)
                .focused($focus, equals: .name)
                .submitLabel(.done)
            if !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: NookSpace.s1) {
                        ForEach(suggestions, id: \.self) { name in
                            FilterChip(verbatim: name, isSelected: false) { choose(name) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Name suggestions"))
            }
        }
        // D35: never rewrite the field while typing; suggestions update after a pause.
        .task(id: draft.name) {
            if !draft.name.isEmpty { nameError = false }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let past = (try? service.pastValues(\.name)) ?? []
            suggestions = focus == .name
                ? ItemSuggestions.suggestions(for: draft.name, past: past, common: CommonItems.all) : []
        }
    }

    private func choose(_ name: String) {
        draft.name = name
        if draft.category.isEmpty, let category = ItemSuggestions.category(for: name, in: CommonItems.all) {
            draft.category = category
        }
        suggestions = []
    }

    // MARK: Where (the Move picker in choose mode, I-04; Save writes through LocationService)

    private var whereRow: some View {
        FieldWell(Text("Where")) {
            Button { choosesPlace = true } label: {
                HStack {
                    Text(verbatim: draft.location?.path ?? String(localized: "Choose a room"))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(draft.location == nil ? NookColor.textSecondary : NookColor.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(NookColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Where"))
            .accessibilityValue(Text(verbatim: draft.location.map { $0.names.joined(separator: ", ") } ?? ""))
            .sheet(isPresented: $choosesPlace) {
                MovePicker(title: Text("Where is it?"), current: draft.location, allowsNoRoom: true) {
                    draft.location = $0
                }
            }
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            FieldWell(Text("Category")) {
                Menu {
                    ForEach(categoryChoices, id: \.self) { category in
                        Button(category) { draft.category = category }
                    }
                    Divider()
                    Button("New Category…", systemImage: "plus") { newCategory = ""; namesCategory = true }
                } label: {
                    HStack {
                        Text(verbatim: draft.category.isEmpty ? String(localized: "Choose") : draft.category)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(draft.category.isEmpty ? NookColor.textSecondary : NookColor.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(NookColor.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("Category"))
                .accessibilityValue(Text(verbatim: draft.category))
            }
            tagsField
            FieldWell(Text("Quantity")) {
                Stepper(value: $draft.quantity, in: 1...9_999) {
                    Text(draft.quantity, format: .number).font(.nookHeadline.monospacedDigit())
                }
                .accessibilityLabel(Text("Quantity"))
            }
            NookTextField(Text("Brand"), text: $draft.brand, prompt: Text("Add brand"))
            NookTextField(Text("Model"), text: $draft.model, prompt: Text("Add model"))
            NookTextField(Text("Serial number"), text: $draft.serial, prompt: Text("Add serial"))
                .fontDesign(.monospaced)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            NookTextField(Text("Barcode"), text: $draft.barcode, prompt: Text("Add barcode"))
                .keyboardType(.numberPad)
        }
    }

    private var categoryChoices: [String] {
        let past = (try? service.pastValues(\.category)) ?? []
        var seen = Set<String>()
        return (past + CommonItems.categories).filter { seen.insert($0.lowercased()).inserted }
    }

    private var tagsField: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            NookTextField(Text("Tags"), text: $tagText, prompt: Text("Add a tag"),
                          helper: Text("Press Return to add each tag."))
                .focused($focus, equals: .tag)
                .submitLabel(.done)
                .onSubmit(addTag)
            if !draft.tags.isEmpty {
                NookFlowLayout(spacing: NookSpace.s1) {
                    ForEach(draft.tags, id: \.self) { tag in
                        Button { draft.tags.removeAll { $0 == tag } } label: {
                            Label { Text(verbatim: tag) } icon: { Image(systemName: "xmark") }
                                .labelStyle(TagTokenStyle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Remove tag \(tag)"))
                    }
                }
            }
        }
    }

    private func addTag() {
        let tag = tagText.trimmingCharacters(in: .whitespaces)
        if !tag.isEmpty, !draft.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
            draft.tags.append(tag)
        }
        tagText = ""
        focus = .tag   // keep typing the next one
    }

    // MARK: Purchase

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            FieldWell(Text("Purchased"), helper: isFuture ? Text("This date is in the future. You can still save.") : nil) {
                if let date = draft.purchaseDate {
                    HStack {
                        DatePicker(selection: Binding { date } set: { draft.purchaseDate = $0 },
                                   displayedComponents: .date) { Text("Purchased") }
                            .labelsHidden()
                        Spacer(minLength: 0)
                        Button("Clear", systemImage: "xmark.circle.fill") { draft.purchaseDate = nil }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(NookColor.textSecondary)
                            .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                            .accessibilityLabel(Text("Clear purchase date"))
                    }
                } else {
                    Button("Add date") { draft.purchaseDate = Calendar.current.startOfDay(for: .now) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            FieldWell(Text("Price")) {
                HStack {
                    TextField(text: $priceText, prompt: Text("0.00").foregroundStyle(NookColor.textSecondary)) {
                        Text("Price")
                    }
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .price)
                    .font(.nookBody.monospacedDigit())
                    .accessibilityLabel(Text("Price"))
                    Picker(selection: $draft.currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text(verbatim: $0).tag($0) }
                    } label: { Text("Currency") }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
            .onChange(of: priceText) { _, text in draft.price = Self.decimal(text) }
            NookTextField(Text("Store"), text: $draft.store, prompt: Text("Where you bought it"))
        }
    }

    private var isFuture: Bool { (draft.purchaseDate ?? .distantPast) > .now }

    private static let currencies: [String] = {
        var codes = Locale.commonISOCurrencyCodes
        if !codes.contains(HomeCurrency.code) { codes.append(HomeCurrency.code) }
        return codes.sorted()
    }()

    private static func decimal(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return try? Decimal(trimmed, format: .number)
    }

    // MARK: Receipt (I-07, C-06)

    private var receiptSection: some View {
        FieldWell(Text("Receipt")) {
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                ForEach(draft.receipts, id: \.fileName) { receipt in
                    HStack {
                        Label(receipt.kind == .pdf ? "PDF receipt" : "Receipt photo",
                              systemImage: receipt.kind == .pdf ? "doc.richtext" : "receipt")
                            .foregroundStyle(NookColor.textPrimary)
                        Spacer(minLength: 0)
                        Button("Remove") { draft.receipts.removeAll { $0 == receipt } }
                            .buttonStyle(.nookTertiary)
                    }
                }
                Menu {
                    if ReceiptScanAvailability.camera {
                        Button("Scan Receipt", systemImage: "doc.viewfinder") { receiptSource = .camera }
                    }
                    Button("Choose File…", systemImage: "folder") { receiptSource = .files }
                    Button("Choose from Photos", systemImage: "photo.on.rectangle") { receiptSource = .photos }
                } label: {
                    Label("Add Receipt", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var privateToggle: some View {
        Toggle(isOn: $draft.isPrivate) {
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text("Private").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                // The lock itself arrives in P12; the flag is stored now.
                Text("Hidden from Spotlight, Siri and widgets. Needs Face ID to open.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
            }
        }
        .padding(NookSpace.s2)
        .nookCard(elevation: .flat)
    }

    // MARK: Files (D40: on disk now, linked on Save)

    private func load(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) { result.append(data) }
        }
        return result
    }

    private func add(photoData: [Data]) {
        let space = ItemService.maxPhotos - draft.photos.count
        Task {
            let blobs = BlobStore.shared
            var added: [ItemDraft.DraftPhoto] = []
            for data in photoData.prefix(space) {
                // Encoding takes a moment per photo; off the main thread.
                let saved = try? await Task.detached { try blobs.savePhoto(data) }.value
                if let saved { added.append(.init(fileName: saved.fileName, width: saved.width, height: saved.height)) }
            }
            if added.count < min(photoData.count, space) { failure = "Some photos couldn’t be added. Try again." }
            draft.photos += added
            if item == nil, draft.name.isEmpty { focus = .name }
        }
    }

    // MARK: Save and discard

    private func save() {
        if !tagText.isEmpty { addTag() }
        do {
            let result: Item
            if let item {
                try service.update(item, from: draft)
                result = item
            } else {
                result = try service.create(draft)
            }
            try context.save()
            saved += 1
            onSave?(result)
            dismiss()
        } catch ItemService.Failure.emptyName {
            nameError = true
            failed += 1
            focus = .name
        } catch {
            context.rollback()
            failed += 1
            failure = "Couldn’t save right now. Your items are safe on this device."
        }
    }

    /// New files from this session are removed now; the sweep would catch them anyway (D40).
    private func discard() {
        let kept = Set(initial.photos.map(\.fileName))
        BlobStore.shared.remove(draft.photos.map(\.fileName).filter { !kept.contains($0) }, in: .photos)
        let keptReceipts = Set(initial.receipts.map(\.fileName))
        BlobStore.shared.remove(draft.receipts.map(\.fileName).filter { !keptReceipts.contains($0) }, in: .receipts)
        dismiss()
    }
}

/// A labeled sunken well for controls that aren't text fields (03 §8.6): menus, steppers,
/// the date and price.
struct FieldWell<Content: View>: View {
    let label: Text
    var helper: Text?
    @ViewBuilder let content: Content

    init(_ label: Text, helper: Text? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.half) {
            label
                .font(.nookFootnote.weight(.semibold))
                .foregroundStyle(NookColor.textSecondary)
                .accessibilityHidden(true)   // the control carries the same label
            content
                .font(.nookBody)
                .padding(.horizontal, NookSpace.s2)
                .padding(.vertical, NookSpace.s1)
                .frame(maxWidth: .infinity, minHeight: NookLayout.fieldHeight, alignment: .leading)
                .background(NookColor.surfaceSunken,
                            in: RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
            if let helper {
                Label { helper } icon: { Image(systemName: "exclamationmark.triangle") }
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.warning)
            }
        }
    }
}

/// A tag as a removable token (03 §8.6).
private struct TagTokenStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: NookSpace.half) {
            configuration.title
            configuration.icon.font(.nookCaption).foregroundStyle(NookColor.textSecondary)
        }
        .font(.nookMeta)
        .foregroundStyle(NookColor.textPrimary)
        .padding(.horizontal, NookSpace.s2)
        .frame(minHeight: NookLayout.minTapTarget)
        .background(NookColor.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(NookColor.hairline, lineWidth: 1) }
    }
}
