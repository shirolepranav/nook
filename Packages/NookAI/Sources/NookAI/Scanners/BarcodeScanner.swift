import SwiftUI
import Vision
import VisionKit

/// The system barcode scanner (C-07): retail codes (EAN-8, EAN-13, UPC-E), Code 128 for
/// store tags, and Nook's own box labels (QR, D19's fallback for the Camera app). The first valid read wins; a retail code must pass its check digit (`EAN`).
/// Lives in NookAI because only NookAI imports VisionKit.
public struct BarcodeScanner: UIViewControllerRepresentable {
    /// False on the simulator and on devices without the scanner (D49); C-07 is manual entry then.
    @MainActor public static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    let found: (String) -> Void

    public init(found: @escaping (String) -> Void) { self.found = found }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128, .qr])],
            qualityLevel: .balanced, recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false, isGuidanceEnabled: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    public func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    public static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    public func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        private var done = false
        init(found: @escaping (String) -> Void) { self.found = found }

        public func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem],
                                allItems: [RecognizedItem]) {
            for item in added {
                guard !done, case .barcode(let barcode) = item, let code = barcode.payloadStringValue,
                      Self.accepts(code, symbology: barcode.observation.symbology) else { continue }
                done = true
                found(code)
            }
        }

        /// Retail codes must check out; Code 128 carries its own check inside the symbol; a QR
        /// code counts only when it's a Nook label.
        static func accepts(_ code: String, symbology: VNBarcodeSymbology) -> Bool {
            switch symbology {
            case .code128: !code.isEmpty
            case .qr: code.hasPrefix("nook://")
            default: EAN.isValid(code)
            }
        }
    }
}
