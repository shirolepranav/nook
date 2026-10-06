import SwiftUI
import NookUI

/// S-01. Rows arrive with their features.
struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppearanceScreen()
                    } label: {
                        Label("Appearance", systemImage: "paintpalette")
                            .frame(minHeight: NookLayout.minTapTarget)
                    }
                }
                .listRowBackground(NookColor.surface)   // paper rows on the canvas (03 §6)
                #if DEBUG
                Section {
                    NavigationLink("Components") { ComponentGallery() }
                        .listRowBackground(NookColor.surface)
                } footer: {
                    Text(verbatim: "Debug builds only: every NookUI component, for design QA.")
                        .foregroundStyle(NookColor.textSecondary)
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
