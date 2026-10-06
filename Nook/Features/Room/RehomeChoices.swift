import SwiftUI
import SwiftData
import NookKit

/// D28: when a room or spot that still holds items is deleted, the dialog asks where they go:
/// another room (or the room itself, for a spot), or Recently Deleted.
struct RehomeChoices: View {
    let itemCount: Int
    let destinations: [Location]
    let deleteTitle: LocalizedStringKey
    let delete: (RoomService.Rehoming?) -> Void

    var body: some View {
        if itemCount == 0 {
            Button(deleteTitle, role: .destructive) { delete(nil) }
        } else {
            ForEach(destinations, id: \.self) { destination in
                Button("Move Items to \(destination.path)") { delete(.move(to: destination)) }
            }
            Button("Move Items to Recently Deleted", role: .destructive) { delete(.recentlyDeleted) }
        }
    }
}

extension RoomService {
    /// Where a deleted room's items can go: every other room.
    func destinations(leaving room: Room) -> [Location] {
        ((try? rooms()) ?? []).filter { $0.id != room.id }.map { Location(room: $0) }
    }

    /// The live items a delete would have to rehome.
    func liveItemCount(in room: Room) -> Int {
        (room.items ?? []).filter { $0.deletedAt == nil }.count
    }

    func liveItemCount(in spot: Spot) -> Int {
        ((spot.items ?? []) + (spot.children ?? []).flatMap { $0.items ?? [] }).filter { $0.deletedAt == nil }.count
    }
}
