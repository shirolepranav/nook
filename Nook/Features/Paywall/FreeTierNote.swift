import SwiftUI
import SwiftData
import NookKit
import NookUI

/// "2 of 3 reminders used." under R-04 and S-07 for Free users (D50, D58), with a way to
/// P-01. Nothing shows once Pro is unlocked.
struct ReminderAllowanceNote: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Query private var warranties: [Warranty]
    @State private var paywall: PaywallRequest?

    var body: some View {
        if !entitlements.isPro {
            let today = Calendar.current.startOfDay(for: .now)
            let used = min(warranties.count { ItemService.isActiveReminder($0, today: today) }, EntitlementStore.freeReminderLimit)
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                Text("\(used) of \(EntitlementStore.freeReminderLimit) reminders used. Unlimited with Nook Pro.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Unlock Nook Pro") { paywall = PaywallRequest(reason: .settings) }
                    .font(.nookFootnote.weight(.semibold))
                    .frame(minHeight: NookLayout.minTapTarget)
            }
            .paywall($paywall)
        }
    }
}
