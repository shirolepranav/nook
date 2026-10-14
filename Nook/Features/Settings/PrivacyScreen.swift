import SwiftUI
import NookUI

/// S-09 Privacy (PRD §9), in plain words. P-01's Privacy link opens it too (D58).
struct PrivacyScreen: View {
    /// Opened as a sheet from P-01: give it a way out.
    var showsDone = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLock.self) private var lock

    var body: some View {
        List {
            section("On this iPhone", "Your items, photos, receipts and answers live on this iPhone. Photos and text are read on this iPhone too.")
            section("With iCloud sync (Pro)", "Items sync through your private iCloud database. Apple encrypts it, and we can’t see it.")
            section("What we collect", "Nothing. No account, no analytics, no ads. The App Store label says “Data Not Collected.”")
            section("Private items", "They need \(lock.method.name) to open and never appear in Spotlight, Siri or widgets.")
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Privacy")
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func section(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        Section {
            Text(text)
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
        }
        .listRowBackground(NookColor.surface)
    }
}

#Preview { NavigationStack { PrivacyScreen() }.environment(AppLock.preview) }
