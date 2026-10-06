import SwiftUI

/// The check circle on a selectable card or row (I-08): filled accent with a check when
/// selected, an empty ring when not.
public struct SelectionMark: View {
    let isSelected: Bool
    @Environment(\.nookAccent) private var accent

    public init(isSelected: Bool) { self.isSelected = isSelected }

    static func label(_ isSelected: Bool) -> Text {
        isSelected ? Text("selected", bundle: .module) : Text("not selected", bundle: .module)
    }

    public var body: some View {
        ZStack {
            Circle().fill(isSelected ? accent.color : NookColor.surfaceRaised.opacity(0.85))
            Circle().strokeBorder(isSelected ? .clear : NookColor.hairlineStrong, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.nookCaption.weight(.bold))
                    .foregroundStyle(accent.onAccent)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)   // a fixed glyph, like card badges
        .frame(width: NookLayout.selectionMarkSize, height: NookLayout.selectionMarkSize)
        .accessibilityHidden(true)   // the card's label says "selected"
        .nookAnimation(.snappy, value: isSelected)
    }
}

/// An item as a list row (03 §4): used where a grid becomes a list at accessibility sizes,
/// and in Recently Deleted (S-08). A square thumbnail, the name, a line under it, and an
/// optional trailing view (a value, "Restore").
public struct ItemRow<Trailing: View>: View {
    let name: String
    let detail: Text
    let photo: Image?
    let isSelected: Bool?
    let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    public init(name: String, detail: Text, photo: Image? = nil, isSelected: Bool? = nil,
                @ViewBuilder trailing: () -> Trailing) {
        self.name = name
        self.detail = detail
        self.photo = photo
        self.isSelected = isSelected
        self.trailing = trailing()
    }

    public var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.s1))
            : AnyLayout(HStackLayout(spacing: NookSpace.s2))
        layout {
            HStack(spacing: NookSpace.s2) {
                if let isSelected { SelectionMark(isSelected: isSelected) }
                NookPhoto(photo)
                    .frame(width: NookLayout.rowThumbnailSize, height: NookLayout.rowThumbnailSize)
                    .containerShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                    .dynamicTypeSize(...DynamicTypeSize.large)   // a fixed-size thumbnail's glyph
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: name)
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textPrimary)
                detail
                    .font(.nookMeta)
                    .foregroundStyle(NookColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            trailing
        }
        .padding(.vertical, NookSpace.s1)
        .frame(minHeight: NookLayout.rowHeight)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
    }
}

public extension ItemRow where Trailing == EmptyView {
    init(name: String, detail: Text, photo: Image? = nil, isSelected: Bool? = nil) {
        self.init(name: name, detail: detail, photo: photo, isSelected: isSelected) { EmptyView() }
    }
}

/// A photo in the editor's strip (I-02): 4:5, the first one captioned "Cover".
public struct PhotoTile: View {
    let photo: Image?
    let isCover: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(photo: Image?, isCover: Bool) {
        self.photo = photo
        self.isCover = isCover
    }

    public var body: some View {
        NookPhoto(photo)
            .frame(width: NookLayout.photoTileWidth, height: NookLayout.photoTileWidth * 5 / 4)
            .containerShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                // At accessibility sizes the caption would cover the photo; VoiceOver still says
                // "Cover" from the tile's value.
                if isCover && !typeSize.isAccessibilitySize {
                    Text("Cover", bundle: .module)
                        .font(.nookCaption)
                        .foregroundStyle(NookColor.textPrimary)
                        .padding(.horizontal, NookSpace.s1)
                        .padding(.vertical, NookSpace.half)
                        .background(NookColor.surfaceRaised, in: Capsule())
                        .padding(NookSpace.half)
                }
            }
    }
}

/// The dashed "add photo" tile at the start of the editor's strip (I-02).
public struct AddPhotoTile: View {
    @Environment(\.nookAccent) private var accent

    public init() {}

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous)
        Image(systemName: "camera.fill")
            .font(.nookSection)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .foregroundStyle(accent.color)
            .frame(width: NookLayout.photoTileWidth, height: NookLayout.photoTileWidth * 5 / 4)
            .overlay { shape.strokeBorder(NookColor.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])) }
            .contentShape(shape)
            .hoverEffect(.highlight)
    }
}
