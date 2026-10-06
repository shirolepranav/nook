import SwiftUI
import SwiftData
import NookKit

/// First run (01 §4): Welcome → Pick your rooms → Home. Under a minute, no permission prompts.
struct OnboardingFlow: View {
    let done: () -> Void

    @State private var showsRooms = false
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            WelcomeScreen { showsRooms = true }
                .navigationDestination(isPresented: $showsRooms) {
                    PickRoomsScreen(finish: createRooms)
                }
        }
    }

    private func createRooms(_ names: [String]) {
        let rooms = RoomService(context: context)
        for name in names {
            _ = try? rooms.addRoom(named: name)   // names come from presets or a trimmed field
        }
        try? context.save()
        done()
    }
}
