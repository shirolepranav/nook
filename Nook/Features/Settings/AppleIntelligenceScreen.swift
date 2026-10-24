import SwiftUI
import NookAI
import NookUI

/// S-11 Apple Intelligence: what the system says, and the app's own "Use Apple Intelligence"
/// (01 S-11, D53). Every state reads as fine, because Nook works the same without it.
struct AppleIntelligenceScreen: View {
    @AppStorage(CapabilityRouter.useAppleIntelligenceKey) private var usesAI = true
    #if DEBUG
    @AppStorage(CapabilityRouter.forceClassicKey) private var forcesClassic = false
    #endif
    @State private var status = NookAI.status
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section { statusCard }
                .listRowBackground(NookColor.surface)
            if showsToggle {
                Section {
                    Toggle(isOn: $usesAI) {
                        VStack(alignment: .leading, spacing: NookSpace.half) {
                            Text("Use Apple Intelligence").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                            Text("Turn off to always tag and fill details yourself.")
                                .font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: NookLayout.minTapTarget)
                }
                .listRowBackground(NookColor.surface)
            }
            #if DEBUG
            // 05 §6: catches code that goes around the router. Debug builds only.
            Section {
                Toggle("Force classic engine", isOn: $forcesClassic).font(.nookBody)
            }
            .listRowBackground(NookColor.surface)
            #endif
            Section {
                Text("Suggestions are made on this iPhone and are always yours to edit. Answers only come from things you’ve saved.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: NookSpace.s2, bottom: 0, trailing: NookSpace.s2))
            }
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Apple Intelligence")
        .toolbarTitleDisplayMode(.large)
        // Back from the Settings app, or the model finished downloading.
        .onChange(of: scenePhase) { _, phase in if phase == .active { status = NookAI.status } }
    }

    /// The board shows the switch only when there's something to switch.
    private var showsToggle: Bool {
        switch status {
        case .ready, .downloading: true
        case .unavailable, .off: false
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            HStack(spacing: NookSpace.s2) {
                Image(systemName: symbol)
                    .font(.nookHeadline)
                    .foregroundStyle(tint)
                    .frame(width: NookLayout.minTapTarget, height: NookLayout.minTapTarget)
                    .background(tint.opacity(0.14), in: Circle())
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .accessibilityHidden(true)
                Text(title).font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
            }
            Text(detail)
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if status == .off {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text("Open Settings").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookSecondary)
            }
        }
        .padding(.vertical, NookSpace.s1)
        .accessibilityElement(children: .contain)
    }

    private var title: LocalizedStringResource {
        switch status {
        case .ready: "Ready"
        case .downloading: "Downloading"
        case .unavailable: "Not available on this iPhone"
        case .off: "Turned off"
        }
    }

    private var detail: LocalizedStringResource {
        switch status {
        case .ready(seesImages: true): "Nook & Cranny can suggest item names from photos, read receipts and answer questions about your home."
        // The vision check (PRD §8): this model reads text but not photos.
        case .ready(seesImages: false): "Nook & Cranny can read receipts and answer questions about your home. You tag items in photos yourself."
        case .downloading: "Apple Intelligence is still getting ready. Everything works as usual in the meantime."
        case .unavailable: "Everything still works. You tag items yourself, and search finds them just as fast."
        case .off: "Apple Intelligence is off in the Settings app. Everything works as usual without it."
        }
    }

    private var symbol: String {
        switch status {
        case .ready: "checkmark"
        case .downloading: "arrow.down"
        case .unavailable: "iphone"
        case .off: "power"
        }
    }

    private var tint: Color {
        switch status {
        case .ready: NookColor.success
        case .downloading: NookColor.info
        case .unavailable, .off: NookColor.textSecondary
        }
    }
}

#if DEBUG
#Preview { NavigationStack { AppleIntelligenceScreen() }.nookAccent(.terracotta) }
#endif
