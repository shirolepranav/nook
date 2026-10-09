import SwiftUI
import NookKit

/// Opens a screen from outside the view tree: a notification tap, or Home's "See all"
/// (04 §7). The shell switches tab, and that tab's root pushes the destination onto its own
/// stack. A one-time request rather than a bound path: rebuilding a bound path on every
/// Home update reset the tab's root, and with it the Capture flow's "Saved" toast.
@Observable @MainActor
final class AppRouter {
    struct Request: Equatable {
        let id = UUID()
        let tab: AppTab
        let destination: Destination
    }

    enum Destination: Equatable {
        case item(Item)
        case report(ReportsRoute)
    }

    /// Cleared by the tab root that pushes it.
    var request: Request?

    func open(_ item: Item) {
        request = Request(tab: .home, destination: .item(item))
    }

    func show(_ route: ReportsRoute) {
        request = Request(tab: .reports, destination: .report(route))
    }
}

/// Screens pushed from Reports (R-04, R-05).
enum ReportsRoute: Hashable {
    case warranties, lentOut
}
