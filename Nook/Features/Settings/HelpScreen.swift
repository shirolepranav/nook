import SwiftUI
import StoreKit
import NookUI

/// S-12 Help & About: tips, contact, version and acknowledgements (D63).
struct HelpScreen: View {
    /// D63: the owner's support address. The release checklist confirms it before submission.
    static let contactAddress = "support@nook.example"

    @Environment(\.requestReview) private var requestReview
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            Section {
                ForEach(HelpTip.allCases) { tip in
                    NavigationLink { HelpTipScreen(tip: tip) } label: { iconRow(tip.title, tip.symbol) }
                }
            } header: {
                header("Tips")
            }
            .listRowBackground(NookColor.surface)
            Section {
                // Mail sends it, so Nook itself makes no network call (PRD §9).
                if let mail = URL(string: "mailto:\(Self.contactAddress)?subject=Nook") {
                    Link(destination: mail) { iconRow("Contact Us", "questionmark.circle") }
                }
                Button { requestReview() } label: { iconRow("Rate Nook", "star") }
                versionRow
                NavigationLink { AcknowledgementsScreen() } label: {
                    Text("Acknowledgements").font(.nookBody).frame(minHeight: NookLayout.minTapTarget)
                }
            } header: {
                header("About")
            }
            .listRowBackground(NookColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Help & About")
        .toolbarTitleDisplayMode(.large)
    }

    private func iconRow(_ title: LocalizedStringKey, _ symbol: String) -> some View {
        HStack(spacing: NookSpace.s2) {
            SettingsIcon(symbol: symbol)
            Text(title).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: NookLayout.minTapTarget)
    }

    /// "Version · 1.0 (1)", stacked at accessibility sizes like S-01's rows (D61).
    private var versionRow: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.half))
            : AnyLayout(HStackLayout())
        return layout {
            Text("Version").font(.nookBody)
            if !typeSize.isAccessibilitySize { Spacer(minLength: NookSpace.s1) }
            Text(verbatim: Self.version).font(.nookMeta).foregroundStyle(NookColor.textSecondary)
        }
        .frame(minHeight: NookLayout.minTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("help.version")
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.nookMeta).foregroundStyle(NookColor.textSecondary).textCase(nil)
    }
}

/// The three tips on the S-12 board, each a short how-to.
enum HelpTip: String, CaseIterable, Identifiable {
    case scan, move, labels
    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .scan: "Scan a room in 30 seconds"
        case .move: "Move things in 2 taps"
        case .labels: "Label boxes for a move"
        }
    }

    var symbol: String {
        switch self {
        case .scan: "viewfinder"
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .labels: "qrcode"
        }
    }

    var steps: [LocalizedStringKey] {
        switch self {
        case .scan: [
            "Tap the Capture button, then Scan room.",
            "Stand back so one shelf or one corner fills the photo.",
            "Check the names, fix any that are off, and tap Save.",
            "No camera handy? Add an item by name instead."
        ]
        case .move: [
            "Find the item, then tap Move.",
            "Pick the new place. Your last five places are at the top.",
            "Changed your mind? Tap Undo on the note that appears."
        ]
        case .labels: [
            "Open a container and tap Print or Share Label.",
            "Stick the label on the box.",
            "Point the Camera app at it later to see what’s inside."
        ]
        }
    }
}

struct HelpTipScreen: View {
    let tip: HelpTip

    var body: some View {
        List {
            Section {
                ForEach(Array(tip.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: NookSpace.s2) {
                        Text(verbatim: "\(index + 1).").font(.nookHeadline).foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(step).font(.nookBody).foregroundStyle(NookColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, NookSpace.half)
                }
            }
            .listRowBackground(NookColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle(tip.title)
        .toolbarTitleDisplayMode(.inline)
    }
}

struct AcknowledgementsScreen: View {
    var body: some View {
        List {
            Section {
                Text("Nook is built only with Apple’s frameworks. It contains no third-party code, no analytics and no ads.")
                Text("Thank you to everyone who tested Nook before it shipped.")
            }
            .font(.nookBody)
            .foregroundStyle(NookColor.textPrimary)
            .listRowBackground(NookColor.surface)
        }
        .scrollContentBackground(.hidden)
        .background(NookColor.canvas)
        .navigationTitle("Acknowledgements")
        .toolbarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview { NavigationStack { HelpScreen() }.nookAccent(.terracotta) }
#endif
