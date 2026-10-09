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
    /// A row in a grouped list.
    public static let rowHeight: CGFloat = 52
    /// Primary and secondary buttons (03 §8.2).
    public static let buttonHeight: CGFloat = 50
    /// Text-field wells (03 §8.6).
    public static let fieldHeight: CGFloat = 48
    /// Corner badges on cards (03 §8.7).
    public static let badgeSize: CGFloat = 24
    /// Empty-state illustrations: 140–180 pt in 03 §8.9; the mockups draw 160.
    public static let illustrationHeight: CGFloat = 160
    /// The welcome illustration (O-01).
    public static let heroIllustrationHeight: CGFloat = 240
    /// The soft circle behind an error or "camera off" symbol (03 §7).
    public static let stateIconSize: CGFloat = 64
    /// Room cards and the dashed add card (03 §8.3): shelf-like, wider than tall.
    public static let roomCardMinHeight: CGFloat = 100
    /// The check circle on a selectable card (I-08 mockup).
    public static let selectionMarkSize: CGFloat = 28
    /// Thumbnails in item rows (S-08 mockup).
    public static let rowThumbnailSize: CGFloat = 56
    /// A card in Home's "Warranties ending soon" row (H-01, P7).
    public static let warrantyCardWidth: CGFloat = 240
    /// Photo tiles in the editor's strip, 4:5 (I-02 mockup: 88 × 110).
    public static let photoTileWidth: CGFloat = 88
    /// The photo hero on item detail (I-01 mockup).
    public static let heroPhotoHeight: CGFloat = 300
    /// The item column beside the detail on a wide window (iPadItem board).
    public static let itemColumnWidth: CGFloat = 360
    /// Accent swatches in Appearance (S-06).
    public static let swatchSize: CGFloat = 48
    /// The floating Capture button (03 §8.1, D26).
    public static let captureButtonSize: CGFloat = 56
    /// The room symbol circle on Move picker rows (I-04 mockup).
    public static let placeIconSize: CGFloat = 32
    /// A dot on the location history timeline (I-05 mockup).
    public static let timelineDotSize: CGFloat = 10
    /// The camera shutter (C-02 mockup).
    public static let shutterSize: CGFloat = 72
    /// Floating glass camera controls: torch, tips, close (C-02 mockup).
    public static let cameraControlSize: CGFloat = 48
    /// A detection outline's stroke (03 §8.5); thicker when selected.
    public static let outlineWidth: CGFloat = 2
    public static let outlineSelectedWidth: CGFloat = 3
}
