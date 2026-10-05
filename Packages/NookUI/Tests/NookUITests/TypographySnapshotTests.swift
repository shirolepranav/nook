import SwiftUI
import Testing
@testable import NookUI

/// Every type token on canvas, so a change to the scale or to Dynamic Type shows up.
private struct TypeSpecimen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NookSpace.s1) {
            Text(verbatim: "Display").font(.nookDisplay)
            Text(verbatim: "Title").font(.nookTitle)
            Text(verbatim: "Section").font(.nookSection)
            Text(verbatim: "Headline").font(.nookHeadline)
            Text(verbatim: "Body text").font(.nookBody)
            Text(verbatim: "Kitchen → Top shelf").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            Text(verbatim: "Footnote").font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
            Text(verbatim: "Caption").font(.nookCaption)
            MoneyText(4380, currencyCode: "USD", font: .nookTotal)
            MoneyText(249.99, currencyCode: "USD")
        }
        .foregroundStyle(NookColor.textPrimary)
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NookColor.canvas)
    }
}

@MainActor
@Test(arguments: SnapshotVariant.all)
func typeScale(variant: SnapshotVariant) throws {
    try assertSnapshot(of: TypeSpecimen(), named: "TypeScale", variant: variant)
}

@MainActor
@Test func hiddenValuesShowDots() throws {
    let defaults = UserDefaults.standard
    defaults.set(true, forKey: MoneyText.hideValuesKey)
    defer { defaults.removeObject(forKey: MoneyText.hideValuesKey) }
    let view = MoneyText(4380, currencyCode: "USD", font: .nookTotal)
        .foregroundStyle(NookColor.textPrimary)
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NookColor.canvas)
    try assertSnapshot(of: view, named: "MoneyHidden", variant: .light)
}
