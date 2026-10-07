import SwiftUI
import AVFoundation
import PhotosUI
import NookUI

/// Whether Nook can use the camera, and what to show when it can't (D15, D49).
enum Camera {
    enum Status { case ready, needsAsking, denied, missing }

    @MainActor static var status: Status {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingCameraDenied") { return .denied }
        if arguments.contains("-uiTestingCameraFixture") { return .ready }
        #endif
        // D49: the simulator has no video device, though the image picker says it has a camera.
        guard AVCaptureDevice.default(for: .video) != nil else { return .missing }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .ready
        case .notDetermined: return .needsAsking
        default: return .denied
        }
    }

    /// The camera can open: it's there and not turned off for Nook.
    @MainActor static var isUsable: Bool { status == .ready || status == .needsAsking }
}

/// The capture session and its queue. `AVCaptureSession` isn't Sendable, so everything that
/// touches it runs on `queue`.
nonisolated final class CaptureSession: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "nook.camera")
    private(set) var device: AVCaptureDevice?
    private var pending: CheckedContinuation<Data?, Never>?

    /// Sets up the back camera and starts it; false when there's no camera to use.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if device == nil {
                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                            ?? AVCaptureDevice.default(for: .video),
                          let input = try? AVCaptureDeviceInput(device: camera),
                          session.canAddInput(input), session.canAddOutput(output)
                    else { continuation.resume(returning: false); return }
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    session.addInput(input)
                    session.addOutput(output)
                    output.maxPhotoQualityPrioritization = .balanced
                    session.commitConfiguration()
                    device = camera
                }
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: true)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            setTorch(false)
            if session.isRunning { session.stopRunning() }
        }
    }

    /// The photo's file data, upright for `angle`; nil if it failed.
    func capture(angle: CGFloat) async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard pending == nil, session.isRunning else { continuation.resume(returning: nil); return }
                pending = continuation
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async { [self] in
            pending?.resume(returning: data)
            pending = nil
        }
    }

    func setTorch(_ on: Bool) {
        queue.async { [self] in
            guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    /// Dim enough that photos come out grainy: the sensor is near its highest ISO (D49).
    func isLowLight() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let device else { continuation.resume(returning: false); return }
                continuation.resume(returning: device.iso >= device.activeFormat.maxISO * 0.8)
            }
        }
    }
}

/// One camera on screen: its permission state, the running session, the torch and the
/// low-light hint (C-02, C-05, C-08).
@Observable @MainActor
final class CameraModel {
    enum State: Equatable { case asking, denied, missing, starting, running, paused }

    private(set) var state: State
    private(set) var isLowLight = false
    var torchOn = false { didSet { session.setTorch(torchOn) } }
    @ObservationIgnored let session = CaptureSession()
    @ObservationIgnored var captureAngle: CGFloat = 90
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    #if DEBUG
    /// UI tests and the simulator's fixture camera: the shutter returns this photo.
    @ObservationIgnored let fixture: UIImage?
    #endif

    init(fixture: @autoclosure () -> UIImage? = nil) {
        state = switch Camera.status {
        case .ready: .starting
        case .needsAsking: .asking
        case .denied: .denied
        case .missing: .missing
        }
        #if DEBUG
        self.fixture = ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") ? fixture() : nil
        if self.fixture != nil { state = .running }
        #endif
    }

    var usesFixture: Bool {
        #if DEBUG
        fixture != nil
        #else
        false
        #endif
    }

    /// The system prompt, after the one-line soft ask (D15).
    func askAccess() async {
        state = await AVCaptureDevice.requestAccess(for: .video) ? .starting : .denied
        if state == .starting { await start() }
    }

    func start() async {
        guard state == .starting, !usesFixture else { return }
        guard await session.start() else { state = .missing; return }
        state = .running
        observeInterruptions()
        // The coach hint shows while the room is too dark (C-02).
        while !Task.isCancelled, state == .running || state == .paused {
            isLowLight = await session.isLowLight()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func stop() {
        session.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    func capture() async -> Data? {
        #if DEBUG
        if let fixture { return fixture.jpegData(compressionQuality: 0.8) }
        #endif
        guard state == .running else { return nil }
        return await session.capture(angle: captureAngle)
    }

    /// A phone call or another app taking the camera pauses it; it resumes by itself, and
    /// the photos taken so far stay (D49).
    private func observeInterruptions() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session.session,
                               queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if self?.state == .running { self?.state = .paused } }
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session.session,
                               queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if self?.state == .paused { self?.state = .running } }
            },
        ]
    }
}

/// The live preview, kept upright as the device turns.
private struct CameraPreview: UIViewRepresentable {
    let camera: CameraModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session.session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let device = camera.session.device {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: view.previewLayer)
            view.rotation = coordinator
            view.observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) {
                [weak view] coordinator, _ in
                let preview = coordinator.videoRotationAngleForHorizonLevelPreview
                let capture = coordinator.videoRotationAngleForHorizonLevelCapture
                Task { @MainActor in
                    view?.previewLayer.connection?.videoRotationAngle = preview
                    camera.captureAngle = capture
                }
            }
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var rotation: AVCaptureDevice.RotationCoordinator?
        var observation: NSKeyValueObservation?
    }
}

/// A camera screen's stage: the preview with the screen's controls on top, or the soft ask,
/// "Camera is off for Nook" or "Camera paused" in its place (C-02 boards). Full screen on
/// every width (01 §1.5).
struct CameraStage<Controls: View>: View {
    let camera: CameraModel
    /// The soft ask's title, e.g. "Photograph your shelves".
    let askTitle: LocalizedStringKey
    let maxPhotos: Int
    /// Photos picked instead of taken, when the camera is off.
    let pickedPhotos: ([Data]) -> Void
    let close: () -> Void
    @ViewBuilder let controls: () -> Controls

    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            switch camera.state {
            case .asking:
                notice(symbol: "camera", title: Text(askTitle),
                       message: Text("Nook uses the camera to take photos of your things. They stay on this device.")) {
                    Button { Task { await camera.askAccess() } } label: {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.nookPrimary)
                    Button("Not Now", action: close).buttonStyle(.nookTertiary)
                }
            case .denied, .missing:
                notice(symbol: "camera.badge.ellipsis",
                       title: camera.state == .denied ? Text("Camera is off for Nook") : Text("No camera here"),
                       message: camera.state == .denied
                           ? Text("Turn it on in Settings, or pick photos you already have.")
                           : Text("Pick photos you already have instead.")) {
                    PhotosPicker(selection: $picked, maxSelectionCount: maxPhotos, matching: .images) {
                        Label("Pick from Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.nookPrimary)
                    if camera.state == .denied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        } label: {
                            Text("Open Settings").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.nookSecondary)
                    }
                    Button("Cancel", action: close).buttonStyle(.nookTertiary)
                }
            case .starting, .running, .paused:
                feed.ignoresSafeArea()
                controls()
                if camera.state == .paused {
                    Label("Camera paused. It picks up where you left off.", systemImage: "pause.circle")
                        .font(.nookBody)
                        .padding(NookSpace.s2)
                        .glassEffect(.regular, in: .rect(cornerRadius: NookRadius.toast))   // a floating camera control (03 §6.3)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .background(camera.state == .asking || camera.state == .denied || camera.state == .missing
                    ? NookColor.canvas : NookColor.cameraFeed)
        .environment(\.colorScheme, camera.state == .running || camera.state == .paused || camera.state == .starting
                     ? .dark : colorScheme)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task {
                var photos: [Data] = []
                for item in items { if let data = try? await item.loadTransferable(type: Data.self) { photos.append(data) } }
                pickedPhotos(photos)
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var feed: some View {
        #if DEBUG
        if let fixture = camera.fixture {
            Image(uiImage: fixture).resizable().scaledToFill().accessibilityHidden(true)
        } else {
            CameraPreview(camera: camera).accessibilityHidden(true)
        }
        #else
        CameraPreview(camera: camera).accessibilityHidden(true)
        #endif
    }

    private func notice(symbol: String, title: Text, message: Text,
                        @ViewBuilder actions: () -> some View) -> some View {
        ScrollView {
            VStack(spacing: NookSpace.s2) {
                Image(systemName: symbol)
                    .font(.nookTitle)
                    .foregroundStyle(NookColor.textSecondary)
                    .frame(width: NookLayout.stateIconSize, height: NookLayout.stateIconSize)
                    .background(NookColor.surfaceSunken, in: Circle())
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .accessibilityHidden(true)
                title
                    .font(.nookSection)
                    .foregroundStyle(NookColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                message
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
                actions()
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(NookSpace.s3)
            .nookCard()
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity, minHeight: NookLayout.heroIllustrationHeight * 3)
        }
    }
}

/// One photo from Nook's camera (C-05 and the editor's Take Photo, C-08's sticker): the
/// shutter, with Choose from Photos and Skip photo beside it (D37). Returns the photo's data,
/// or nil for Skip; `cancel` closes without a choice.
struct SinglePhotoCamera: View {
    var askTitle: LocalizedStringKey = "Photograph your things"
    var hint: LocalizedStringKey?
    var offersSkip = true
    var fixture: UIImage?
    let completion: (Data?) -> Void
    let cancel: () -> Void

    @State private var camera: CameraModel?
    @State private var picked: PhotosPickerItem?
    @State private var busy = false

    var body: some View {
        Group {
            if let camera {
                CameraStage(camera: camera, askTitle: askTitle, maxPhotos: 1,
                            pickedPhotos: { if let first = $0.first { completion(first) } }, close: cancel) {
                    controls(camera)
                }
            }
        }
        .onAppear { if camera == nil { camera = CameraModel(fixture: fixture ?? CaptureFixtures.shelf) } }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { if let data = try? await item.loadTransferable(type: Data.self) { completion(data) } }
        }
    }

    private func controls(_ camera: CameraModel) -> some View {
        VStack {
            HStack {
                CameraControl(Text("Cancel"), systemImage: "xmark", action: cancel)
                Spacer()
                if camera.session.device?.hasTorch == true {
                    CameraControl(Text("Torch"), systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                  isOn: camera.torchOn) { camera.torchOn.toggle() }
                }
            }
            if let hint {
                Text(hint)
                    .font(.nookMeta)
                    .padding(.horizontal, NookSpace.s2)
                    .padding(.vertical, NookSpace.s1)
                    .glassEffect(.regular, in: .capsule)
            }
            Spacer()
            HStack(alignment: .center) {
                PhotosPicker(selection: $picked, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.nookHeadline)
                        .frame(width: NookLayout.cameraControlSize, height: NookLayout.cameraControlSize)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Choose from Photos"))
                Spacer()
                ShutterButton {
                    guard !busy else { return }
                    busy = true
                    Task {
                        if let data = await camera.capture() { completion(data) }
                        busy = false
                    }
                }
                .disabled(camera.state != .running)
                Spacer()
                if offersSkip {
                    Button("Skip") { completion(nil) }
                        .font(.nookHeadline)
                        .frame(minWidth: NookLayout.cameraControlSize, minHeight: NookLayout.cameraControlSize)
                        .buttonStyle(.glass)
                        .accessibilityLabel(Text("Skip photo"))
                } else {
                    Color.clear.frame(width: NookLayout.cameraControlSize, height: NookLayout.cameraControlSize)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(NookSpace.s2)
    }
}
