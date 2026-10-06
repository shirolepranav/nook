import SwiftUI
import NookUI

/// O-01 Welcome: the promise, privacy in one line, one button. No permission prompts (01 §4).
struct WelcomeScreen: View {
    let getStarted: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s4) {
                VStack(alignment: .leading, spacing: NookSpace.s3) {
                    IllustrationView(.shelfTidy)
                        .padding(NookSpace.s3)
                        .frame(maxWidth: .infinity)
                        .frame(height: NookLayout.heroIllustrationHeight)
                        .background(NookColor.surfaceSunken,
                                    in: RoundedRectangle(cornerRadius: NookRadius.hero, style: .continuous))
                    Text("Know what you own and where it is.")
                        .font(.nookDisplay)
                        .foregroundStyle(NookColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Snap a room, tag what’s on the shelves, and ask where anything is, any time.")
                        .font(.nookBody)
                        .foregroundStyle(NookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: NookSpace.s2) {
                    // The catalog says "iPad" on iPad (01 §1.3, D29) through a device variation.
                    Label("Everything stays on your device. No account.", systemImage: "lock.fill")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .frame(maxWidth: .infinity)
                    Button(action: getStarted) {
                        Text("Get Started").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.nookPrimary)
                }
            }
            .padding(.horizontal, NookSpace.s3)
            .padding(.vertical, NookSpace.s4)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
    }
}

#Preview { WelcomeScreen {}.nookAccent(.terracotta) }
