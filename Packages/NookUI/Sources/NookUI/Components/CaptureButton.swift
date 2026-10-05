import SwiftUI

/// The floating Capture button (03 §8.1, D26): a 56 pt Liquid Glass circle tinted with the
/// accent, bottom trailing above the tab bar. One of only two custom glass controls (03 §6.3).
/// `showsGlow` adds a soft accent ring on Home until the first item is saved (D26).
public struct CaptureButton: View {
    let showsGlow: Bool
    let action: () -> Void

    @State private var taps = 0
    @Environment(\.nookAccent) private var accent

    public init(showsGlow: Bool = false, action: @escaping () -> Void) {
        self.showsGlow = showsGlow
        self.action = action
    }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.nookTitle)
                .frame(width: NookLayout.captureButtonSize, height: NookLayout.captureButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .background {
            if showsGlow {
                Circle()
                    .strokeBorder(accent.suggested, lineWidth: NookSpace.half)
                    .padding(-NookSpace.s1)
                    .accessibilityHidden(true)
            }
        }
        // The glyph keeps its size at large text sizes; the button is already 56 pt.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(Text("Capture", bundle: .module))
        .accessibilityHint(Text("Scan a room, add an item, or scan a receipt or barcode", bundle: .module))
        .nookHaptic(.tick, trigger: taps)
    }
}
