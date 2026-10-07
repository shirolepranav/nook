import UIKit

/// Stand-in photos for the camera and scanners in UI tests and the simulator, which has no
/// camera (D37, D49). `-uiTestingCameraFixture` turns them on; release builds have none.
enum CaptureFixtures {
    /// A shelf with three things on it, for C-02 and C-05.
    static var shelf: UIImage? {
        #if DEBUG
        render(CGSize(width: 1200, height: 900)) { context, size in
            UIColor.systemBrown.withAlphaComponent(0.35).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBrown.setFill()
            context.fill(CGRect(x: 0, y: size.height * 0.75, width: size.width, height: size.height * 0.05))
            for (index, color) in [UIColor.systemRed, .systemTeal, .systemYellow].enumerated() {
                color.setFill()
                UIBezierPath(roundedRect: CGRect(x: 120 + CGFloat(index) * 360, y: 320, width: 240, height: 355),
                             cornerRadius: 30).fill()
            }
        }
        #else
        nil
        #endif
    }

    /// A receipt whose numbers the tests know: TOTAL $766.41 on 09/14/2026 (C-06, S6).
    static var receipt: UIImage? {
        #if DEBUG
        paper(["HOME GOODS CO.", "412 Maple Ave", "", "09/14/2026  14:32", "", "ESPRESSO MCH    649.00",
               "2-YR PROTECTION  59.00", "", "SUBTOTAL        708.00", "TAX              58.41",
               "TOTAL          $766.41", "", "THANK YOU"])
        #else
        nil
        #endif
    }

    /// A serial sticker (C-08).
    static var sticker: UIImage? {
        #if DEBUG
        paper(["BREWMASTER", "MODEL: EM-4200", "S/N: 7XK2-48812-QA", "MFD 2025-03", "120V ~ 60Hz 1350W"])
        #else
        nil
        #endif
    }

    /// A valid EAN-13 (C-07).
    static let barcode = "4006381333931"

    #if DEBUG
    /// Printed paper: black on white, whatever the app's appearance.
    private static func paper(_ lines: [String]) -> UIImage {
        let font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .title2).pointSize, weight: .regular)
        let height = CGFloat(lines.count + 2) * font.lineHeight * 1.3
        return render(CGSize(width: 900, height: max(height, 600))) { context, size in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 60, y: font.lineHeight * (1 + CGFloat(index) * 1.3)),
                                        withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
    }

    private static func render(_ size: CGSize, draw: (UIGraphicsImageRendererContext, CGSize) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0, size) }
    }
    #endif
}
