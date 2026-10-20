import SwiftUI
import StoreKit
import NookKit
import NookUI

/// S-02 Nook Pro (PRD §7): what's included, Restore Purchases and the Family Sharing note.
struct ProScreen: View {
    @Environment(EntitlementStore.self) private var entitlements
    @State private var paywall: PaywallRequest?
    @State private var restoring = false
    @State private var toast: ToastMessage?

    var body: some View {
        List {
            Section {
                if entitlements.isPro { unlocked } else { unlockButton }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            Section {
                included("square.stack.3d.up", "Unlimited items", "Free keeps up to 25.")
                included("bell", "Unlimited warranty reminders", "Free keeps up to 3.")
                included("doc.richtext", "Insurance report and CSV", "Free shows a preview.")
                included("icloud", "iCloud sync", "Keep all your devices in step.")
            } header: {
                Text("What’s included").font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
            }
            .listRowBackground(NookColor.surface)
            Section {
                Button(action: restore) {
                    Label(restoring ? "Restoring…" : "Restore Purchases", systemImage: "arrow.clockwise")
                        .font(.nookBody)
                        .frame(minHeight: NookLayout.minTapTarget)
                }
                .disabled(restoring)
                .listRowBackground(NookColor.surface)
                Text("Bought Nook Pro before, or on another device? Restore it here. Family Sharing is on, so your family gets Pro too.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: NookSpace.s1, leading: NookSpace.s2, bottom: 0, trailing: NookSpace.s2))
            }
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Nook Pro")
        .toolbarTitleDisplayMode(.large)
        .paywall($paywall)
        .toast($toast)
    }

    private var unlockButton: some View {
        Button { paywall = PaywallRequest(reason: .settings) } label: {
            Text("Unlock Nook Pro").frame(maxWidth: .infinity)
        }
        .buttonStyle(.nookPrimary)
    }

    /// "Nook Pro is unlocked · Bought Oct 4, 2026."
    private var unlocked: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Label {
                Text("Nook Pro is unlocked").font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            } icon: {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(NookColor.success)
            }
            switch entitlements.ownership {
            case .purchased(let date):
                Text("Bought \(date.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            case .familyShared:
                Text("Shared with you through Family Sharing.")
                    .font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            case nil:
                EmptyView()
            }
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .combine)
    }

    private func included(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(spacing: NookSpace.s2) {
            SettingsIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                Text(detail).font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: NookLayout.minTapTarget)
        .accessibilityElement(children: .combine)
    }

    private func restore() {
        restoring = true
        Task {
            let found = await entitlements.restore()
            restoring = false
            toast = found
                ? ToastMessage(symbol: "checkmark.seal.fill", "Nook Pro is unlocked.")
                : ToastMessage(symbol: "info.circle", "No purchase found for this Apple Account.")
        }
    }
}

/// The accent-tinted square icon on S-01's Pro card and S-02's rows.
struct SettingsIcon: View {
    let symbol: String
    var filled = false
    @Environment(\.nookAccent) private var accent

    var body: some View {
        Image(systemName: symbol)
            .font(filled ? .nookSection : .nookMeta.weight(.semibold))
            .foregroundStyle(filled ? accent.onAccent : accent.color)
            .frame(width: filled ? NookLayout.swatchSize : NookLayout.placeIconSize,
                   height: filled ? NookLayout.swatchSize : NookLayout.placeIconSize)
            .background(filled ? accent.color : accent.suggested, in: .rect(cornerRadius: filled ? NookRadius.medium : NookRadius.small))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview { NavigationStack { ProScreen() }.environment(EntitlementStore(forcedPro: false)) }
#endif
