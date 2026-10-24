import SwiftUI
import UIKit
import NookUI

/// L-02 App Lock (PRD F11, §9): an opaque warm cover with the Nook mark and Unlock. A failure
/// says so with an error haptic and a gentle pulse, and the button stays. While Nook is only
/// out of view (the app switcher), the same cover shows without the button.
struct LockCover: View {
    let lock: AppLock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulses = false

    var body: some View {
        ZStack {
            NookColor.canvas
            if pulses { NookColor.danger.opacity(0.08) }
            // Centered, and scrolls once large text no longer fits (03 §11).
            GeometryReader { proxy in
                ScrollView {
                    content.frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .ignoresSafeArea(edges: .horizontal)
        .background(NookColor.canvas.ignoresSafeArea())
        .nookHaptic(.failed, trigger: lock.failures)
        .onChange(of: lock.failures) { _, failures in
            guard failures > 0, !reduceMotion else { return }
            withNookAnimation(.fade, reduceMotion: reduceMotion) { pulses = true }
            Task {
                try? await Task.sleep(for: .seconds(NookMotion.fadeSeconds))
                withNookAnimation(.fade, reduceMotion: reduceMotion) { pulses = false }
            }
        }
    }

    private var content: some View {
            VStack(spacing: NookSpace.s3) {
                Image("LaunchMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: NookLayout.lockMarkSize, height: NookLayout.lockMarkSize)
                    .accessibilityHidden(true)
                if lock.isLocked {
                    Text("Nook & Cranny is locked")
                        .font(.nookTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(NookColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if lock.failures > 0 {
                        Text("\(lock.method.name) didn’t recognize you. Try again, or use your passcode.")
                            .font(.nookMeta)
                            .foregroundStyle(NookColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Unlock with \(lock.method.name)", systemImage: lock.method.symbol)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NookButtonStyle(.primary))
                    .frame(maxWidth: NookLayout.readableWidth)
                }
            }
            .multilineTextAlignment(.center)
            .padding(NookSpace.s3)
    }
}

extension View {
    /// L-02 and the app-switcher cover, in a window above Nook's, so they cover open sheets
    /// too. Face ID is asked as soon as Nook comes back locked (01 L-02).
    func appLock(_ lock: AppLock, accent: AccentChoice, theme: ColorScheme?) -> some View {
        modifier(AppLockModifier(lock: lock, accent: accent, theme: theme))
    }
}

private struct AppLockModifier: ViewModifier {
    let lock: AppLock
    let accent: AccentChoice
    let theme: ColorScheme?
    @Environment(\.scenePhase) private var scenePhase
    @State private var window = LockWindow()

    func body(content: Content) -> some View {
        content
            .nookHaptic(.saved, trigger: lock.unlocks)
            .onChange(of: scenePhase, initial: true) { _, phase in
                lock.sceneChanged(to: phase)
                update()
                if phase == .active, lock.isLocked { Task { await lock.unlock() } }
            }
            .onChange(of: lock.isLocked) { update() }
            .onChange(of: lock.privateUnlocked) { update() }
            .onChange(of: accent) { update() }
            .onChange(of: theme) { update() }
    }

    private func update() {
        window.show(lock.covers(scenePhase), lock: lock, accent: accent, theme: theme)
    }
}

/// The cover's own window, at alert level. It's built on first use and kept, so showing it
/// as Nook leaves the screen is synchronous and lands in the app-switcher snapshot.
@MainActor
private final class LockWindow {
    private var window: UIWindow?
    private var accent: AccentChoice?

    // ponytail: the first connected scene; v1.0 has one window (D30). P15 covers each scene.
    func show(_ covered: Bool, lock: AppLock, accent: AccentChoice, theme: ColorScheme?) {
        guard covered || window != nil,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let window = self.window ?? UIWindow(windowScene: scene)
        if self.window == nil {
            window.windowLevel = .alert + 1
            self.window = window
        }
        if self.accent != accent {
            window.rootViewController = UIHostingController(rootView: LockCover(lock: lock).nookAccent(accent))
            self.accent = accent
        }
        window.overrideUserInterfaceStyle = switch theme {
        case .light: .light
        case .dark: .dark
        default: .unspecified
        }
        if covered {
            window.alpha = 1
            window.isHidden = false
        } else if !window.isHidden {
            // Cross-fade away (01 L-02); a fade is allowed under Reduce Motion (03 §9).
            UIView.animate(withDuration: NookMotion.fadeSeconds) { window.alpha = 0 } completion: { _ in
                if window.alpha == 0 { window.isHidden = true }
            }
        }
    }
}
