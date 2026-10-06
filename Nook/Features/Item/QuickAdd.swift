import SwiftUI
import AVFoundation
import NookKit
import NookUI

extension View {
    /// C-05 Quick add (D37): the camera first, then the editor with the photo in place, so
    /// shutter and Save are the 2 taps (F2). With the camera off or missing, the editor opens
    /// straight away and offers Photos. P6 replaces the system camera with Nook's own.
    func quickAdd(isPresented: Binding<Bool>, at location: Location? = nil) -> some View {
        modifier(QuickAdd(isPresented: isPresented, location: location))
    }
}

private struct QuickAdd: ViewModifier {
    @Binding var isPresented: Bool
    let location: Location?

    @State private var showsCamera = false
    @State private var editor: EditorStart?
    @State private var photo: ItemDraft.DraftPhoto?
    @State private var toast: ToastMessage?

    private struct EditorStart: Identifiable {
        let id = UUID()
        let draft: ItemDraft
        let cameraOff: Bool
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, start in
                guard start else { return }
                isPresented = false
                photo = nil
                if Camera.isUsable { showsCamera = true } else { openEditor(cameraOff: true) }
            }
            .fullScreenCover(isPresented: $showsCamera, onDismiss: { if photo != nil { openEditor(cameraOff: false) } }) {
                CameraSheet { data in
                    guard let data, let saved = try? BlobStore.shared.savePhoto(data) else { return }
                    photo = .init(fileName: saved.fileName, width: saved.width, height: saved.height)
                }
                .ignoresSafeArea()
            }
            .sheet(item: $editor) { start in
                ItemEditor(draft: start.draft, cameraOff: start.cameraOff) { item in
                    toast = item.room.map { ToastMessage("Saved to \($0.name).") } ?? ToastMessage("Saved.")
                }
            }
            .toast($toast)
    }

    private func openEditor(cameraOff: Bool) {
        var draft = ItemDraft(currencyCode: HomeCurrency.code, location: location)
        draft.photos = photo.map { [$0] } ?? []
        editor = EditorStart(draft: draft, cameraOff: cameraOff)
    }
}

/// Whether to show the camera. Asking happens just in time, when the camera opens (D15).
enum Camera {
    @MainActor static var isUsable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") { return true }
        #endif
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return false }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status != .denied && status != .restricted
    }
}

/// The system camera, returning the photo's data, or nil when cancelled.
struct CameraSheet: View {
    let completion: (Data?) -> Void

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingCameraFixture") {
            FixtureCamera(completion: completion)   // simulators have no camera
        } else {
            SystemCamera(completion: completion)
        }
        #else
        SystemCamera(completion: completion)
        #endif
    }
}

private struct SystemCamera: UIViewControllerRepresentable {
    let completion: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemCamera
        init(_ parent: SystemCamera) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image?.heicData() ?? image?.jpegData(compressionQuality: 0.9))
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            parent.dismiss()
        }
    }
}

#if DEBUG
/// UI tests: a stand-in camera whose shutter returns a fixed photo (D37).
private struct FixtureCamera: View {
    let completion: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: NookSpace.s3) {
            Spacer()
            Button("Take Photo") {
                let renderer = ImageRenderer(content: NookColor.surfaceSunken.frame(width: 400, height: 500))
                completion(renderer.uiImage?.jpegData(compressionQuality: 0.8))
                dismiss()
            }
            .buttonStyle(.nookPrimary)
            Button("Cancel") { completion(nil); dismiss() }
            Spacer()
        }
        .padding(NookSpace.s3)
        .background(NookColor.canvas)
    }
}
#endif
