import SwiftUI
import NookKit
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
                            .font(.nookBody)
                            .frame(minHeight: NookLayout.minTapTarget)
                    }
                }
                .listRowBackground(NookColor.surface)
                Section {
                    NavigationLink {
                        RecentlyDeletedScreen()
                    } label: {
                        Label("Recently Deleted", systemImage: "trash")
                            .font(.nookBody)
                            .frame(minHeight: NookLayout.minTapTarget)
                    }
                }
                .listRowBackground(NookColor.surface)   // paper rows on the canvas (03 §6)
                #if DEBUG
                // Debug builds only: every NookUI component, for design QA. No footer: low on
                // the screen, the audit misreads its text as unscalable.
                Section {
                    NavigationLink("Components") { ComponentGallery() }
                        .listRowBackground(NookColor.surface)
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            // The last rows can scroll clear of the floating Capture button (as in TabRoot).
            .contentMargins(.bottom, NookLayout.captureButtonSize + NookSpace.s2, for: .scrollContent)
            .background(NookColor.canvas)
            .captureButton()
            .navigationTitle("Settings")
        }
    }
}

#Preview { SettingsScreen().nookAccent(.terracotta) }
