import Testing
import UIKit
@testable import Nook

// D30: v1.0 shows one window. Remove when P15 turns multiple windows on.
@MainActor
@Test func appSupportsOneWindowOnly() {
    #expect(!UIApplication.shared.supportsMultipleScenes)
}
