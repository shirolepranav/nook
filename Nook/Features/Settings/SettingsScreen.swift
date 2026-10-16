import SwiftUI
import SwiftData
import NookKit
import NookAI
import NookUI

/// S-01. Rows arrive with their features.
struct SettingsScreen: View {
    @AppStorage(CapabilityRouter.useAppleIntelligenceKey) private var usesAI = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var aiStatus = NookAI.status
    @State private var paywall: PaywallRequest?
    // Type-erased: S-10 pushes its own routes and items too (P13).
    @State private var path = NavigationPath()
    @AppStorage(SyncSettings.key) private var syncOn = false
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppRouter.self) private var router
    @Environment(AppLock.self) private var lock
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var liveItems: [Item]   // S-10's count

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // Grouped as on the S-01 board; rows join their sections as features arrive.
                Section { proCard }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                Section {
                    NavigationLink(value: SettingsRoute.sync) {
                        rowLabel("iCloud Sync", "icloud", detail: !entitlements.isPro ? "Pro" : syncOn ? "On" : "Off")
                    }
                    row("Backup & Restore", "externaldrive") { BackupScreen() }
                    row("Recently Deleted", "trash") { RecentlyDeletedScreen() }
                } header: {
                    header("Your data")
                }
                .listRowBackground(NookColor.surface)
                Section {
                    // S-05 leads the Privacy section (01 S-01).
                    NavigationLink { LockScreen() } label: {
                        rowLabel("\(lockName) Lock", lock.method.symbol, detail: lock.isEnabled ? "On" : "Off")
                    }
                    row("Privacy", "hand.raised") { PrivacyScreen() }
                } header: {
                    header("Privacy")
                }
                .listRowBackground(NookColor.surface)
                Section {
                    row("Appearance", "paintpalette") { AppearanceScreen() }
                    row("Notifications", "bell") { NotificationsScreen() }
                    // S-10, by value: it pushes values of its own, and a closure link here pushed it twice.
                    NavigationLink(value: SettingsRoute.tags) {
                        rowLabel("Tags", "tag", detail: "\(ItemService.tagCounts(in: liveItems).count)")
                    }
                    row("Apple Intelligence", "apple.intelligence", detail: aiDetail) { AppleIntelligenceScreen() }
                    row("Help & About", "questionmark.circle") { HelpScreen() }   // S-12 (D63)
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
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .sync: SyncScreen()
                case .pro: ProScreen()
                case .tags: TagsScreen()
                }
            }
            .paywall($paywall)
            .onAppear {
                // Back on S-03 after its switch reopened the store (D58).
                if router.reopensSync { path = NavigationPath([SettingsRoute.sync]); router.reopensSync = false }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { aiStatus = NookAI.status } }
        }
    }

    /// Free: "Unlock Nook Pro" opens P-01. Pro: a thank-you that leads to S-02.
    @ViewBuilder
    private var proCard: some View {
        if entitlements.isPro {
            // A Button, not a NavigationLink: in a List the link adds a second chevron.
            Button { path.append(SettingsRoute.pro) } label: {
                cardLabel(Text("Nook Pro"), Text("Thank you for supporting Nook."))
            }
            .buttonStyle(.nookCard)
        } else {
            Button { paywall = PaywallRequest(reason: .settings) } label: {
                cardLabel(Text("Unlock Nook Pro"), Text("Unlimited items, reports and iCloud sync. Pay once."))
            }
            .buttonStyle(.nookCard)
        }
    }

    private func cardLabel(_ title: Text, _ detail: Text) -> some View {
        HStack(spacing: NookSpace.s2) {
            SettingsIcon(symbol: "shippingbox.fill", filled: true)
            VStack(alignment: .leading, spacing: 0) {
                title.font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
                detail.font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.nookFootnote.weight(.semibold))
                .foregroundStyle(NookColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, detail: LocalizedStringKey? = nil,
                     @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink(destination: destination) { rowLabel(title, symbol, detail: detail) }
    }

    private func rowLabel(_ title: LocalizedStringKey, _ symbol: String, detail: LocalizedStringKey?) -> some View {
        // Side by side, stacked at accessibility sizes so a long title ("Face ID Lock") and
        // its detail never squeeze each other (as in D50's rows).
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
            : AnyLayout(HStackLayout())
        return layout {
            Label(title, systemImage: symbol).font(.nookBody)
            if !typeSize.isAccessibilitySize { Spacer(minLength: NookSpace.s1) }
            if let detail { Text(detail).font(.nookMeta).foregroundStyle(NookColor.textSecondary) }
        }
        .frame(minHeight: NookLayout.minTapTarget)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
    }

    /// "Face ID", or Face ID when the device has no passcode to lock with.
    private var lockName: String {
        lock.method == .unavailable ? AppLock.Method.faceID.name : lock.method.name
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

/// Screens Settings opens by value, so it can reopen S-03 (D58).
enum SettingsRoute: Hashable { case sync, pro, tags }

#if DEBUG
#Preview {
    SettingsScreen().nookAccent(.terracotta)
        .environment(EntitlementStore(forcedPro: false))
        .environment(AppRouter())
        .environment(SyncStatus())
        .environment(AppLock.preview)
}
#endif
