import SwiftUI
import NookKit
import NookUI

/// S-03 iCloud Sync (Pro, D8, D58): the switch, when it last synced, Sync Now, and the two
/// problems worth a card: signed out and storage full. Everything stays on this device either
/// way (01 §1.3).
struct SyncScreen: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(SyncStatus.self) private var status
    @Environment(\.openURL) private var openURL
    @AppStorage(SyncSettings.key) private var isOn = false
    @State private var paywall: PaywallRequest?
    @State private var syncing = false
    @State private var switching = false

    var body: some View {
        List {
            if !entitlements.isPro {
                Section { freeCard }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } else if isOn, status.state == .signedOut {
                Section {
                    problem("person.crop.circle.badge.exclamationmark", "You’re signed out of iCloud",
                            "Sign in to iCloud in the Settings app to sync. Your items are safe on this iPhone.",
                            action: "Open Settings")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } else if isOn, status.state == .storageFull {
                Section {
                    problem("externaldrive.badge.exclamationmark", "Your iCloud storage is full",
                            "Syncing pauses until there’s space. Your items are safe on this iPhone.",
                            action: "Manage Storage")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                Toggle(isOn: toggle) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sync with iCloud").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                        Text("Items, photos and moves sync through your private iCloud. We can’t see them.")
                            .font(.nookFootnote)
                            .foregroundStyle(NookColor.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(switching)
                .frame(minHeight: NookLayout.minTapTarget)
                if entitlements.isPro, isOn {
                    lastSyncedRow
                    Button {
                        syncing = true
                        Task { await status.syncNow(); syncing = false }
                    } label: {
                        Label(syncing ? "Syncing…" : "Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            .font(.nookBody)
                            .frame(minHeight: NookLayout.minTapTarget)
                    }
                    .disabled(syncing || status.state == .signedOut)
                }
            }
            .listRowBackground(NookColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("iCloud Sync")
        .toolbarTitleDisplayMode(.large)
        .paywall($paywall)
    }

    /// Free: turning it on opens P-01, and sync starts after the unlock (D9, D58).
    private var toggle: Binding<Bool> {
        Binding {
            entitlements.isPro && isOn
        } set: { on in
            guard entitlements.isPro else {
                if on { paywall = PaywallRequest(reason: .sync) { change(to: true) } }
                return
            }
            change(to: on)
        }
    }

    private func change(to on: Bool) {
        switching = true
        Task { await status.setSync(on); switching = false }
    }

    private var lastSyncedRow: some View {
        HStack {
            Text("Last synced").font(.nookBody).foregroundStyle(NookColor.textPrimary)
            Spacer(minLength: NookSpace.s1)
            Group {
                if status.state == .syncing {
                    Text("Syncing…")
                } else if let date = status.lastSynced {
                    Text(date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                } else {
                    Text("Not yet")
                }
            }
            .font(.nookMeta)
            .foregroundStyle(NookColor.textSecondary)
        }
        .frame(minHeight: NookLayout.minTapTarget)
        .accessibilityElement(children: .combine)
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Label {
                Text("iCloud sync comes with Nook Pro").font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            } icon: {
                Image(systemName: "icloud").foregroundStyle(NookColor.info)
            }
            Text("Your items stay on this iPhone. With Pro, they sync to your other devices through your own iCloud.")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { paywall = PaywallRequest(reason: .sync) { change(to: true) } } label: {
                Text("Unlock Nook Pro").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
    }

    /// A calm card: the reason, the reassurance, one action (01 §1.3). Both open the Settings
    /// app; iOS has no link to the iCloud pages themselves.
    private func problem(_ symbol: String, _ title: LocalizedStringKey, _ message: LocalizedStringKey,
                         action: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Label {
                Text(title).font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            } icon: {
                Image(systemName: symbol).foregroundStyle(NookColor.warning)
            }
            Text(message)
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } } label: {
                Text(action).frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookSecondary)
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack { SyncScreen() }
        .environment(EntitlementStore(forcedPro: false))
        .environment(SyncStatus())
}
