import UIKit

/// Navigation-bar titles in the type tokens (03 §3, §8.8): large rounded titles on tab
/// roots, rounded inline titles on detail screens, in `textPrimary`. SwiftUI has no modifier
/// for the bar's title font, so this goes through UIKit's appearance proxy once at launch.
public enum NookAppearance {
    @MainActor
    public static func configure() {
        let text = UIColor(named: "textPrimary", in: .module, compatibleWith: nil) ?? .label
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(.largeTitle, weight: .bold), .foregroundColor: text]
        bar.titleTextAttributes = [.font: rounded(.headline, weight: .semibold), .foregroundColor: text]
    }

    /// The text style's size, rounded and weighted, still scaled by Dynamic Type.
    private static func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style,
                                                            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let descriptor = (base.withDesign(.rounded) ?? base)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
    }
}
