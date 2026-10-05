import SwiftUI
import NookUI

/// S-01. Rows arrive with their features; Appearance (S-06) is next in P1.
struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                Section {
                    NavigationLink("Components") { ComponentGallery() }
                } footer: {
                    Text(verbatim: "Debug builds only: every NookUI component, for design QA.")
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .captureButton()
            .navigationTitle("Settings")
        }
    }
}

#Preview { SettingsScreen().nookAccent(.terracotta) }
