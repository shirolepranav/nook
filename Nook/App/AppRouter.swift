import SwiftUI
import NookKit

/// Opens a screen from outside the view tree: a notification tap, or Home's "See all"
/// (04 §7). The shell switches tab; each tab root pushes onto its own stack.
@Observable @MainActor
final class AppRouter {
    /// A tab the shell should switch to; it clears it once done.
    var requestedTab: AppTab?
    var homePath = NavigationPath()
    var reportsPath = NavigationPath()

    func open(_ item: Item) {
        requestedTab = .home
        homePath = NavigationPath([item])
    }

    func show(_ route: ReportsRoute) {
        requestedTab = .reports
        reportsPath = NavigationPath([route])
    }
}

/// Screens pushed from Reports (R-04, R-05).
enum ReportsRoute: Hashable {
    case warranties, lentOut
}
