import AVFoundation
import SwiftUI
import VisionKit

/// The system document camera (C-06): finds the receipt's edges, flattens it and takes as
/// many pages as the user wants. Lives in NookAI because only NookAI imports VisionKit.
public struct DocumentScanner: UIViewControllerRepresentable {
    /// D49: `isSupported` is true on the simulator, which has no camera, so a camera must exist too.
    @MainActor public static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported && AVCaptureDevice.default(for: .video) != nil
    }

    /// The pages, upright, or nil when cancelled or failed.
    let completion: ([CGImage]?) -> Void

    public init(completion: @escaping ([CGImage]?) -> Void) { self.completion = completion }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    public func updateUIViewController(_ camera: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: ([CGImage]?) -> Void
        init(completion: @escaping ([CGImage]?) -> Void) { self.completion = completion }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                                 didFinishWith scan: VNDocumentCameraScan) {
            completion((0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage })
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(nil)
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                                 didFailWithError error: any Error) {
            completion(nil)
        }
    }
}
