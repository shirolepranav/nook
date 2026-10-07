import SwiftUI

// Capture pieces (03 §8.5, 01 C-02–C-08). Boxes are normalized 0–1 with a top-left origin.

/// One detection outline (03 §8.5): a soft rounded outline in the accent at 80%, drawn on
/// when it appears (a fade under Reduce Motion). Selected: thicker and filled at 15%.
public struct DetectionOutline: View {
    let isSelected: Bool
    let drawsOn: Bool
    @State private var drawn: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.nookAccent) private var accent

    public init(isSelected: Bool = false, drawsOn: Bool = true) {
        self.isSelected = isSelected
        self.drawsOn = drawsOn
        _drawn = State(initialValue: drawsOn ? 0 : 1)
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
        ZStack {
            shape.fill(accent.color.opacity(isSelected ? 0.15 : 0))
            shape.trim(from: 0, to: reduceMotion ? 1 : drawn)
                .stroke(accent.color.opacity(0.8),
                        style: StrokeStyle(lineWidth: isSelected ? NookLayout.outlineSelectedWidth : NookLayout.outlineWidth,
                                           lineCap: .round))
                // A faint glow in light mode, where the photo is often bright.
                .shadow(color: colorScheme == .light ? accent.color.opacity(0.4) : .clear, radius: NookSpace.half)
        }
        .opacity(reduceMotion ? drawn : 1)
        .onAppear {
            guard drawn < 1 else { return }
            withNookAnimation(.settle, reduceMotion: reduceMotion) { drawn = 1 }
        }
        .nookAnimation(.snappy, value: isSelected)
    }
}

/// Outlines over a photo, revealed one after another with a light tap each (03 §8.5, §9).
/// Each box is a button named for its item ("Box 2, Lamp"), so VoiceOver and Voice Control
/// can pick it; tapping one selects its card.
public struct DetectionOverlay: View {
    let boxes: [CGRect]
    let names: [String]
    let selected: Int?
    let reveals: Bool
    let select: (Int) -> Void

    @State private var shown: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(boxes: [CGRect], names: [String], selected: Int? = nil, reveals: Bool = true,
                select: @escaping (Int) -> Void = { _ in }) {
        self.boxes = boxes
        self.names = names
        self.selected = selected
        self.reveals = reveals
        self.select = select
        _shown = State(initialValue: reveals ? 0 : boxes.count)
    }

    public var body: some View {
        GeometryReader { proxy in
            ForEach(Array(boxes.prefix(shown).enumerated()), id: \.offset) { index, box in
                let frame = CGRect(x: box.minX * proxy.size.width, y: box.minY * proxy.size.height,
                                   width: box.width * proxy.size.width, height: box.height * proxy.size.height)
                Button { select(index) } label: {
                    DetectionOutline(isSelected: selected == index, drawsOn: reveals)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityLabel(Text("Box \(index + 1), \(index < names.count ? names[index] : "")", bundle: .module))
                .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
        }
        .nookHaptic(.tick, trigger: shown)
        .task(id: boxes.count) {
            // New boxes join one at a time; removed ones go at once.
            if shown > boxes.count { shown = boxes.count }
            while shown < boxes.count {
                try? await Task.sleep(for: NookMotion.stagger(reduceMotion: reduceMotion))
                guard !Task.isCancelled else { return }
                shown += 1
            }
        }
    }
}

/// A recognized number or date on a receipt (C-06, Classic): tap it to drop it into the
/// focused field. The best candidate is filled in the accent; used ones fade back.
/// The visible chip is the size of the printed text; the tap area is at least 44 pt.
public struct ScanHighlight: View {
    let label: Text
    let size: CGSize
    let isBest: Bool
    let isUsed: Bool
    let action: () -> Void

    @Environment(\.nookAccent) private var accent

    public init(_ label: Text, size: CGSize, isBest: Bool = false, isUsed: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.size = size
        self.isBest = isBest
        self.isUsed = isUsed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: NookRadius.small / 2, style: .continuous)
                .fill(isBest ? accent.suggested : accent.color.opacity(0.08))
                .strokeBorder(accent.color.opacity(isUsed ? 0.3 : 0.9), lineWidth: isBest ? NookLayout.outlineSelectedWidth : NookLayout.outlineWidth)
                .frame(width: size.width + NookSpace.s1, height: size.height + NookSpace.half)
                .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(Text("Fills the selected field", bundle: .module))
    }
}

/// The camera's shutter (C-02, C-05, C-08): white in both modes, like the system camera.
public struct ShutterButton: View {
    let action: () -> Void
    @State private var taps = 0

    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: NookSpace.half)
                Circle().fill(.white).padding(NookSpace.s1)
            }
            .frame(width: NookLayout.shutterSize, height: NookLayout.shutterSize)
            .contentShape(Circle())
        }
        .buttonStyle(ShutterPressStyle())
        .accessibilityLabel(Text("Take Photo", bundle: .module))
        .nookHaptic(.tick, trigger: taps)
    }
}

private struct ShutterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .nookAnimation(.snappy, value: configuration.isPressed)
    }
}

/// A floating camera control (torch, tips, close): a Liquid Glass circle, one of the
/// custom glass controls 03 §6.3 allows.
public struct CameraControl: View {
    let title: Text
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    public init(_ title: Text, systemImage: String, isOn: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.nookHeadline)
                .frame(width: NookLayout.cameraControlSize, height: NookLayout.cameraControlSize)
        }
        .buttonStyle(isOn ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
        .buttonBorderShape(.circle)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)   // the circle is already 48 pt
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Type-erases the two glass styles so the control can switch between them.
private struct AnyButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init<Style: PrimitiveButtonStyle>(_ style: Style) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// The last photo taken with the count on it (C-02's multi-photo counter).
public struct PhotoCounter: View {
    let count: Int
    let thumbnail: Image?

    @Environment(\.nookAccent) private var accent

    public init(count: Int, thumbnail: Image?) {
        self.count = count
        self.thumbnail = thumbnail
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
            .fill(NookColor.surfaceSunken)
            .overlay {
                thumbnail?.resizable().scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
                    .strokeBorder(.white, lineWidth: NookLayout.outlineWidth)
            }
            .frame(width: NookLayout.cameraControlSize, height: NookLayout.cameraControlSize)
            .overlay(alignment: .topTrailing) {
                Text(count, format: .number)
                    .font(.nookCaption.monospacedDigit())
                    .foregroundStyle(accent.onAccent)
                    .padding(.horizontal, NookSpace.half)
                    .frame(minWidth: NookLayout.badgeSize, minHeight: NookLayout.badgeSize)
                    .background(accent.color, in: Capsule())
                    .offset(x: NookSpace.s1, y: -NookSpace.s1)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("^[\(count) photo](inflect: true) taken", bundle: .module))
    }
}

#Preview("Capture pieces") {
    ZStack {
        NookColor.textPrimary
        VStack(spacing: NookSpace.s3) {
            DetectionOverlay(boxes: [CGRect(x: 0.1, y: 0.1, width: 0.35, height: 0.5),
                                     CGRect(x: 0.55, y: 0.3, width: 0.35, height: 0.4)],
                             names: ["Toaster", "Blender"], selected: 1)
                .frame(height: 200)
            HStack(spacing: NookSpace.s3) {
                PhotoCounter(count: 2, thumbnail: nil)
                ShutterButton {}
                CameraControl(Text(verbatim: "Torch"), systemImage: "flashlight.on.fill", isOn: true) {}
            }
        }
        .padding(NookSpace.s2)
    }
    .nookAccent(.terracotta)
}
