import SwiftUI
import NookKit
import NookUI

/// H-01's one gentle nudge (D65): "Your 40 things live only on this iPhone." Shown once a
/// home is worth keeping, or once after Pro is bought outside S-03. A card, never a sheet.
struct DataSafetyCard: View {
    let items: [Item]

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(SyncStatus.self) private var syncStatus
    @Environment(AppRouter.self) private var router
    @AppStorage(SyncSettings.key) private var syncOn = false
    @AppStorage(PreferenceKey.lastBackup) private var lastBackup: Double = 0
    @AppStorage(PreferenceKey.dataNudgeDismissals) private var dismissals = 0
    @AppStorage(PreferenceKey.dataNudgeDismissedAt) private var dismissedAt: Double = 0
    @AppStorage(PreferenceKey.syncOffer) private var offered = false
    @State private var paywall: PaywallRequest?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if isDue { card.paywall($paywall) }
    }

    private var isDue: Bool {
        #if DEBUG
        // UI tests see it only when they ask, so seeded homes keep their usual Home.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingStore"), !arguments.contains("-uiTestingDataNudge") { return false }
        #endif
        let safety = DataSafety.state(syncs: entitlements.isPro && syncOn, syncState: syncStatus.state,
                                      lastSynced: syncStatus.lastSynced,
                                      lastBackup: lastBackup > 0 ? Date(timeIntervalSince1970: lastBackup) : nil, now: .now)
        let fullestRoom = Dictionary(grouping: items.compactMap { $0.room?.id }, by: { $0 }).values.map(\.count).max() ?? 0
        return DataSafetyNudge.isDue(safety: safety, itemCount: items.count, fullestRoom: fullestRoom,
                                     offered: offered && entitlements.isPro, dismissals: dismissals,
                                     lastDismissed: dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil, now: .now)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Label {
                Text("Your \(items.count) things live only on this iPhone.")
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textPrimary)
            } icon: {
                Image(systemName: "icloud").foregroundStyle(NookColor.info)
            }
            Text("Turn on iCloud sync and they’ll follow you to any new device.")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
            // Side by side, stacked at accessibility sizes (as S-01's rows, D50).
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: NookSpace.s1)) : AnyLayout(HStackLayout(spacing: NookSpace.s1))
            layout {
                Button(action: turnOn) { Text("Turn On").frame(maxWidth: .infinity) }
                    .buttonStyle(.nookPrimary)
                    .accessibilityLabel(Text("Turn On iCloud Sync"))
                Button(action: notNow) { Text("Not Now").frame(maxWidth: .infinity) }
                    .buttonStyle(.nookSecondary)
            }
            if !entitlements.isPro {
                // Free has no sync, but it has backups (D65); no one is pushed to pay to be safe.
                NavigationLink { BackupScreen() } label: {
                    Text("Or make a backup file").font(.nookFootnote.weight(.semibold))
                        .frame(minHeight: NookLayout.minTapTarget)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .contain)
    }

    /// Pro turns sync on as S-03's switch does; Free goes through P-01 first (D58).
    private func turnOn() {
        let start = { [syncStatus, router] in
            Task {
                await syncStatus.setSync(true)
                router.reopensSync = false   // stay on Home; S-03 isn't where this began
            }
        }
        offered = false
        if entitlements.isPro { _ = start() } else { paywall = PaywallRequest(reason: .sync) { _ = start() } }
    }

    private func notNow() {
        withAnimation {
            dismissals += 1
            dismissedAt = Date.now.timeIntervalSince1970
            offered = false
        }
    }
}
