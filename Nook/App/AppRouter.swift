import SwiftUI
import NookKit

/// Opens things from outside the view tree: a notification tap (04 §7), and links from
/// widgets, controls, Spotlight and intents (`link`, 04 §8). The shell shows them in sheets. Tab roots keep their own stacks: binding them to shared state reset Home's
/// root, and with it the Capture flow's "Saved" toast (D50).
@Observable @MainActor
final class AppRouter {
    var openedItem: Item?
    /// A box label scanned with the Camera app (F8): the container in a sheet.
    var openedSpot: Spot?
    /// A room from Spotlight or a link.
    var openedRoom: Room?
    /// R-04, from the Warranties widget.
    var showsWarranties = false
    /// A link for the shell to open (Spotlight, intents); it clears it.
    var link: DeepLink?
    /// AddItemIntent: the editor, with the name and place filled in.
    var newItem: NewItemRequest?
    /// What Find's field should say next (`nook://find?q=`); Find clears it.
    var findQuery: String?
    /// Set when the store reopens after S-03's switch, so Settings comes back on S-03 (D58).
    var reopensSync = false

    func open(_ item: Item) {
        openedItem = item
    }
}

struct NewItemRequest: Equatable {
    var name: String
    var place: UUID?
}

/// Screens pushed from Reports, and from Home's See All (R-04, R-05).
enum ReportsRoute: Hashable {
    case warranties, lentOut, insuranceReport
}
