import CoreGraphics

/// Spacing on the 8-pt grid (03 §4, D6). `half` only for tight gaps inside a component.
public enum NookSpace {
    public static let half: CGFloat = 4
    public static let s1: CGFloat = 8
    public static let s2: CGFloat = 16
    public static let s3: CGFloat = 24
    public static let s4: CGFloat = 32
    public static let s5: CGFloat = 40
    public static let s6: CGFloat = 48
}

/// Corner radii (03 §5). Always used with the continuous corner style.
/// Capsules use `Capsule()`; photos inside cards use `ConcentricRectangle()`.
public enum NookRadius {
    public static let small: CGFloat = 8     // badges, tiny thumbnails
    public static let medium: CGFloat = 12   // text fields, list thumbnails
    public static let card: CGFloat = 24     // photo cards, room cards
    public static let hero: CGFloat = 32     // answer card, onboarding panels
    public static let toast: CGFloat = 20    // toasts (from the mockups; 03 §5)
}

/// Wide-window rules (03 §4, D29). Named `NookLayout` because SwiftUI already has `Layout`.
public enum NookLayout {
    /// Narrowest photo card before a grid drops a column.
    public static let cardMinWidth: CGFloat = 160
    /// Most photo-grid columns at any width.
    public static let maxGridColumns = 6
    /// Widest column for forms, settings and long text.
    public static let readableWidth: CGFloat = 640
    /// Widest a photo grid gets: `maxGridColumns` cards plus the gaps between them.
    public static let maxGridWidth = cardMinWidth * CGFloat(maxGridColumns) + NookSpace.s2 * CGFloat(maxGridColumns - 1)
    /// Smallest tap target (03 §4).
    public static let minTapTarget: CGFloat = 44

    // Component sizes from 03 §8 and the mockups.
    /// Primary and secondary buttons (03 §8.2).
    public static let buttonHeight: CGFloat = 50
    /// Text-field wells (03 §8.6).
    public static let fieldHeight: CGFloat = 48
    /// Corner badges on cards (03 §8.7).
    public static let badgeSize: CGFloat = 24
    /// Empty-state illustrations: 140–180 pt in 03 §8.9; the mockups draw 160.
    public static let illustrationHeight: CGFloat = 160
    /// The soft circle behind an error or "camera off" symbol (03 §7).
    public static let stateIconSize: CGFloat = 64
    /// Room cards and the dashed add card (03 §8.3): shelf-like, wider than tall.
    public static let roomCardMinHeight: CGFloat = 100
    /// The floating Capture button (03 §8.1, D26).
    public static let captureButtonSize: CGFloat = 56
}
