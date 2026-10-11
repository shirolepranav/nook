import SwiftUI
import NookKit
import NookAI
import NookUI

/// S-01. Rows arrive with their features.
struct SettingsScreen: View {
    @AppStorage(CapabilityRouter.useAppleIntelligenceKey) private var usesAI = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var aiStatus = NookAI.status

    var body: some View {
        NavigationStack {
            List {
                // Grouped as on the S-01 board; rows join their sections as features arrive.
                Section {
                    row("Recently Deleted", "trash") { RecentlyDeletedScreen() }
                } header: {
                    header("Your data")
                }
                .listRowBackground(NookColor.surface)
                Section {
                    row("Appearance", "paintpalette") { AppearanceScreen() }
                    row("Notifications", "bell") { NotificationsScreen() }
                    row("Apple Intelligence", "apple.intelligence", detail: aiDetail) { AppleIntelligenceScreen() }
                } header: {
                    header("Nook")
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
            .onChange(of: scenePhase) { _, phase in if phase == .active { aiStatus = NookAI.status } }
        }
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, detail: LocalizedStringKey? = nil,
                     @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Label(title, systemImage: symbol).font(.nookBody)
                Spacer(minLength: NookSpace.s1)
                if let detail { Text(detail).font(.nookMeta).foregroundStyle(NookColor.textSecondary) }
            }
            .frame(minHeight: NookLayout.minTapTarget)
        }
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
    }

    /// S-01's "Ready" beside Apple Intelligence.
    private var aiDetail: LocalizedStringKey {
        switch aiStatus {
        case .ready: usesAI ? "Ready" : "Off"
        case .downloading: "Downloading"
        case .unavailable: "Not available"
        case .off: "Off"
        }
    }
}

#Preview { SettingsScreen().nookAccent(.terracotta) }
