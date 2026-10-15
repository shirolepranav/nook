import SwiftUI
import NookUI

/// S-05 Face ID Lock (PRD F11, D28): the switch, Lock after, and the note that Private items
/// always ask. With no passcode on the device there's nothing to lock with, so the switch is
/// off and Settings is one tap away.
struct LockScreen: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var lock = lock
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                if lock.method == .unavailable { unavailableCard }
                Toggle(isOn: Binding { lock.isEnabled } set: { on in Task { await lock.setEnabled(on) } }) {
                    Text("Lock Nook with \(lock.method.name)").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                }
                .disabled(lock.method == .unavailable)
                .frame(minHeight: NookLayout.minTapTarget)
                .padding(.horizontal, NookSpace.s2)
                .nookCard()

                if lock.isEnabled {
                    VStack(alignment: .leading, spacing: NookSpace.s1) {
                        Text("Lock after")
                            .font(.nookFootnote.weight(.semibold))
                            .foregroundStyle(NookColor.textSecondary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, NookSpace.s2)
                        // The segmented control doesn't grow with text size (D51).
                        if typeSize.isAccessibilitySize {
                            timingPicker($lock.timing).pickerStyle(.menu)
                        } else {
                            timingPicker($lock.timing).pickerStyle(.segmented)
                        }
                    }
                }

                Label {
                    Text("Private items always need \(lock.method.name) to open, even with the lock off. The app switcher hides Nook while it’s locked.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .padding(.horizontal, NookSpace.s2)
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .navigationTitle(Text("\(lock.method == .unavailable ? AppLock.Method.faceID.name : lock.method.name) Lock"))
        .toolbarTitleDisplayMode(.large)
    }

    private func timingPicker(_ timing: Binding<LockTiming>) -> some View {
        Picker("Lock after", selection: timing) {
            ForEach(LockTiming.allCases) { Text($0.title).tag($0) }
        }
        .nookHaptic(.selected, trigger: timing.wrappedValue)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Text("Set a passcode in Settings to lock Nook.")
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(NookButtonStyle(.secondary, isCompact: true))
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
    }
}

#if DEBUG
#Preview {
    NavigationStack { LockScreen() }
        .environment(AppLock.preview)
}
#endif
