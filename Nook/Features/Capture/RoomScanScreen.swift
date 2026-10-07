import SwiftUI
import PhotosUI
import SwiftData
import NookKit
import NookUI

extension View {
    /// C-02 → C-04: scan a room with Nook's camera, then tag what's in the photos. With no
    /// camera at all (the simulator, some iPads), the photo picker opens straight into tagging
    /// (D48). `location` is where the items go, changeable on both screens.
    func roomScan(isPresented: Binding<Bool>, at location: Location? = nil) -> some View {
        modifier(RoomScanPresenter(isPresented: isPresented, location: location))
    }
}

/// A photo taken or picked for a room scan, already on disk (D40).
struct ScanPhoto: Identifiable, Equatable {
    let fileName: String
    let width: Int
    let height: Int
    var id: String { fileName }

    /// Encodes off the main thread; nil when the data isn't an image.
    static func save(_ data: Data) async -> ScanPhoto? {
        let blobs = BlobStore.shared
        guard let saved = try? await Task.detached(operation: { try blobs.savePhoto(data) }).value else { return nil }
        return ScanPhoto(fileName: saved.fileName, width: saved.width, height: saved.height)
    }
}

private struct RoomScanPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let location: Location?

    @State private var start: ScanStart?
    @State private var picksPhotos = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var toast: ToastMessage?
    @Environment(\.modelContext) private var context

    struct ScanStart: Identifiable {
        let id = UUID()
        var photos: [ScanPhoto] = []
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shows in
                guard shows else { return }
                isPresented = false
                if Camera.status == .missing { picksPhotos = true } else { start = ScanStart() }
            }
            .photosPicker(isPresented: $picksPhotos, selection: $picked, maxSelectionCount: RoomScanScreen.maxPhotos,
                          matching: .images)
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                picked = []
                Task {
                    var photos: [ScanPhoto] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let photo = await ScanPhoto.save(data) {
                            photos.append(photo)
                        }
                    }
                    if !photos.isEmpty { start = ScanStart(photos: photos) }
                }
            }
            .fullScreenCover(item: $start) { start in
                RoomScanScreen(photos: start.photos, location: location) { saved in
                    self.start = nil
                    guard let saved else { return }
                    toast = savedToast(saved)
                }
            }
            .toast($toast)
    }

    /// "6 items saved to Garage." with Undo, which deletes them for good (they're new).
    private func savedToast(_ items: [Item]) -> ToastMessage {
        let undo = {
            ItemService(context: context).deleteNow(items)
            try? context.save()
        }
        if let room = items.first?.room?.name {
            return ToastMessage("^[\(items.count) item](inflect: true) saved to \(room).", undo: undo)
        }
        return ToastMessage("^[\(items.count) item](inflect: true) saved.", undo: undo)
    }
}

/// C-02 Room scan camera, then C-04 Manual tagging (Classic). Full screen on every width
/// (01 §1.5). `finish` gets the saved items, or nil when cancelled.
struct RoomScanScreen: View {
    /// ponytail: a scan is up to 10 photos, like an item's photos (D7); more is a second scan.
    static let maxPhotos = ItemService.maxPhotos

    @State private var photos: [ScanPhoto]
    @State private var location: Location?
    @State private var tagging: Bool
    let finish: ([Item]?) -> Void

    init(photos: [ScanPhoto] = [], location: Location?, finish: @escaping ([Item]?) -> Void) {
        _photos = State(initialValue: photos)
        _location = State(initialValue: location)
        _tagging = State(initialValue: !photos.isEmpty)
        self.finish = finish
    }

    var body: some View {
        if tagging {
            ManualTagScreen(photos: photos, location: $location) { saved in
                BlobStore.shared.remove(photos.map(\.fileName), in: .photos)   // only the crops are kept (D48)
                finish(saved)
            }
        } else {
            RoomScanCamera(photos: $photos, location: $location) { done in
                if done { tagging = true } else {
                    BlobStore.shared.remove(photos.map(\.fileName), in: .photos)
                    finish(nil)
                }
            }
        }
    }
}

/// C-02: camera, coach hint, shutter, counter, where the items go, and Done.
private struct RoomScanCamera: View {
    @Binding var photos: [ScanPhoto]
    @Binding var location: Location?
    let close: (_ done: Bool) -> Void

    @State private var camera = CameraModel(fixture: CaptureFixtures.shelf)
    @State private var lastThumb: Image?
    @State private var showsTips = false
    @State private var choosesPlace = false
    @State private var confirmsDiscard = false
    @State private var saving = 0
    @AppStorage("hasScannedRoom") private var hasScanned = false

    var body: some View {
        CameraStage(camera: camera, askTitle: "Photograph your shelves", maxPhotos: RoomScanScreen.maxPhotos,
                    pickedPhotos: addPicked, close: { close(false) }) {
            VStack(spacing: NookSpace.s2) {
                HStack(alignment: .top) {
                    CameraControl(Text("Cancel"), systemImage: "xmark") {
                        photos.isEmpty ? close(false) : (confirmsDiscard = true)
                    }
                    Spacer()
                    destination
                    Spacer()
                    VStack(spacing: NookSpace.s1) {
                        if camera.session.device?.hasTorch == true {
                            CameraControl(Text("Torch"), systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                          isOn: camera.torchOn) { camera.torchOn.toggle() }
                        }
                        CameraControl(Text("Tips"), systemImage: "questionmark", isOn: showsTips) { showsTips.toggle() }
                    }
                }
                Spacer()
                if let hint { coach(hint) }
                Spacer()
                HStack {
                    PhotoCounter(count: photos.count, thumbnail: lastThumb)
                        .opacity(photos.isEmpty ? 0 : 1)
                    Spacer()
                    ShutterButton(action: shoot)
                        .disabled(camera.state != .running || photos.count + saving >= RoomScanScreen.maxPhotos)
                    Spacer()
                    Button("Done") { close(true) }
                        .font(.nookHeadline)
                        .frame(minWidth: NookLayout.cameraControlSize, minHeight: NookLayout.cameraControlSize)
                        .buttonStyle(.glassProminent)
                        .disabled(photos.isEmpty || saving > 0)
                }
            }
            .padding(NookSpace.s2)
        }
        .onAppear { if !hasScanned { showsTips = true; hasScanned = true } }   // the first scan coaches (01 O-02)
        .sheet(isPresented: $choosesPlace) {
            MovePicker(title: Text("Where are these?"), current: location, allowsNoRoom: true) { location = $0 }
        }
        .confirmationDialog(Text("Discard ^[\(photos.count) photo](inflect: true)?"), isPresented: $confirmsDiscard,
                            titleVisibility: .visible) {
            Button("Discard Photos", role: .destructive) { close(false) }
            Button("Keep Scanning", role: .cancel) {}
        }
    }

    /// "Saving to: Garage → Shelf", tappable to change it.
    private var destination: some View {
        Button { choosesPlace = true } label: {
            VStack(spacing: 0) {
                Text("Saving to").font(.nookCaption)
                Text(verbatim: location?.path ?? String(localized: "Choose a room"))
                    .font(.nookMeta.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, NookSpace.s2)
            .frame(minHeight: NookLayout.cameraControlSize)
        }
        .buttonStyle(.glass)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Saving to"))
        .accessibilityValue(Text(verbatim: location?.names.joined(separator: ", ") ?? String(localized: "Choose a room")))
    }

    /// Low light first, then the tips (first scan, or the Tips button).
    private var hint: LocalizedStringResource? {
        if camera.isLowLight { return "It’s a little dark. Turn on more lights or the torch." }
        return showsTips ? "Step back a little so the whole shelf fits. Take a photo of each shelf, then tap Done." : nil
    }

    private func coach(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.nookBody)
            .multilineTextAlignment(.center)
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth / 1.5)
            .glassEffect(.regular, in: .rect(cornerRadius: NookRadius.toast))   // a floating camera control (03 §6.3)
            .onTapGesture { showsTips = false }
            .accessibilityAddTraits(.isStaticText)
            .onAppear { AccessibilityNotification.Announcement(String(localized: text)).post() }
    }

    /// Each photo goes to disk at the shutter (D40), so an interrupted scan leaves only
    /// orphans for the sweep.
    private func shoot() {
        saving += 1
        Task {
            defer { saving -= 1 }
            guard let data = await camera.capture(), let photo = await ScanPhoto.save(data) else { return }
            photos.append(photo)
            if let thumb = await BlobStore.shared.thumbnail(photo.fileName) { lastThumb = Image(decorative: thumb, scale: 1) }
        }
    }

    private func addPicked(_ data: [Data]) {
        Task {
            for each in data.prefix(RoomScanScreen.maxPhotos - photos.count) {
                if let photo = await ScanPhoto.save(each) { photos.append(photo) }
            }
            if !photos.isEmpty { close(true) }
        }
    }
}
