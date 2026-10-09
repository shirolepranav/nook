import SwiftUI
import NookKit
import NookUI

/// S-07 Notifications: warranty and loan reminders, and the time of day they come (F4, F7).
/// When iOS has them turned off, a card says so and opens Settings (01 §13).
struct NotificationsScreen: View {
    @AppStorage(PreferenceKey.warrantyReminders) private var warranties = true
    @AppStorage(PreferenceKey.loanReminders) private var loans = true
    @AppStorage(PreferenceKey.reminderMinutes) private var minutes = 9 * 60
    @Environment(\.reminders) private var reminders
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            if reminders?.isDenied == true {
                Section { deniedCard }
                    .listRowBackground(NookColor.surface)
            }
            Section {
                Toggle(isOn: $warranties) {
                    row(Text("Warranty reminders"), Text("30 and 7 days before a warranty ends"))
                }
                Toggle(isOn: $loans) {
                    row(Text("Loan reminders"), Text("The morning something is due back"))
                }
                // A plain label beside the picker, stacked at accessibility sizes so it can grow;
                // the picker's own label and a section footer don't (the audit flags both).
                let row = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.s1)) : AnyLayout(HStackLayout())
                row {
                    Text("Time of day").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DatePicker(selection: time, displayedComponents: .hourAndMinute) { Text("Time of day") }
                        .labelsHidden()
                }
                .frame(minHeight: NookLayout.minTapTarget)
            } header: {
                Text("Reminders").font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
            }
            .listRowBackground(NookColor.surface)
            Section {
                Text("Nook only sends reminders you asked for.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: NookSpace.s2, bottom: 0, trailing: NookSpace.s2))
            }
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.large)
        .onChange(of: [warranties, loans]) { reschedule() }
        .onChange(of: minutes) { reschedule() }
    }

    private func row(_ title: Text, _ detail: Text) -> some View {
        VStack(alignment: .leading, spacing: NookSpace.half) {
            title.font(.nookBody).foregroundStyle(NookColor.textPrimary)
            detail.font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            HStack(spacing: NookSpace.s2) {
                Image(systemName: "bell.slash")
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.warning)
                    .frame(width: NookLayout.minTapTarget, height: NookLayout.minTapTarget)
                    .background(NookColor.warning.opacity(0.14), in: Circle())
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .accessibilityHidden(true)
                Text("Reminders are off for Nook").font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            }
            Text("Turn on notifications in the Settings app so warranty and loan reminders can reach you.")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Text("Open Settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookSecondary)
        }
        .padding(.vertical, NookSpace.s1)
        .accessibilityElement(children: .contain)
    }

    /// Minutes after midnight, shown as a time today.
    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    private func reschedule() {
        Task { await reminders?.reconcile() }
    }
}

#Preview { NavigationStack { NotificationsScreen() }.nookAccent(.terracotta) }
