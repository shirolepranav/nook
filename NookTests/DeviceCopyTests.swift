import Testing
import UIKit
@testable import Nook

// 01 §1.3, D29: copy that names the device says "iPad" on iPad. The catalog's device
// variations do it, so the views never branch on the device (D57).
@MainActor
@Test(arguments: [
    "Not available on this iPhone",
    "Everything is made on this iPhone. It takes about 20 seconds.",
    "Your items are safe on this iPhone. Try again in a moment.",
])
func deviceCopyNamesTheDevice(_ key: String) {
    let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"   // tests may ask; the app doesn't
    #expect(String(localized: String.LocalizationValue(key), bundle: .main) == key.replacingOccurrences(of: "iPhone", with: device))
}
