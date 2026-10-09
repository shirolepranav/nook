import SwiftUI
import NookKit

/// Opens an item from outside the view tree: a notification tap (04 §7). The shell shows it
/// in a sheet. Tab roots keep their own stacks: binding them to shared state reset Home's
/// root, and with it the Capture flow's "Saved" toast (D50).
@Observable @MainActor
final class AppRouter {
    var openedItem: Item?

    func open(_ item: Item) {
        openedItem = item
    }
}

/// Screens pushed from Reports, and from Home's See All (R-04, R-05).
enum ReportsRoute: Hashable {
    case warranties, lentOut
}
