import SwiftUI
import NookUI

/// S-06 Appearance: theme, the accent (1 of 6, D5) and Hide values by default.
struct AppearanceScreen: View {
    @AppStorage(PreferenceKey.theme) private var theme: ThemeChoice = .system
    @AppStorage(PreferenceKey.accent) private var accent: AccentChoice = .terracotta
    @AppStorage(PreferenceKey.hideValuesByDefault) private var hideValuesByDefault = false
    @AppStorage(PreferenceKey.hideValues) private var hideValues = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                VStack(alignment: .leading, spacing: NookSpace.s1) {
                    label("Theme")
                    Picker("Theme", selection: $theme) {
                        ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .nookHaptic(.selected, trigger: theme)
                }

                VStack(alignment: .leading, spacing: NookSpace.s2) {
                    label("Accent color")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NookSpace.s2), count: 3),
                              spacing: NookSpace.s2) {
                        ForEach(AccentChoice.allCases) { choice in
                            AccentSwatch(choice: choice, isSelected: choice == accent) { accent = choice }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("Accent color"))
                    .nookHaptic(.selected, trigger: accent)
                }
                .padding(NookSpace.s2)
                .nookCard()

                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Toggle("Hide values by default", isOn: $hideValuesByDefault)
                        .font(.nookBody)
                        .foregroundStyle(NookColor.textPrimary)
                        .frame(minHeight: NookLayout.minTapTarget)
                    Text("Prices show as •••• until you tap the eye on Home.")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                }
                .padding(NookSpace.s2)
                .nookCard()
                .onChange(of: hideValuesByDefault) { hideValues = $1 }   // show the effect right away
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .navigationTitle("Appearance")
        .toolbarTitleDisplayMode(.large)
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.nookFootnote.weight(.semibold))
            .foregroundStyle(NookColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One accent: a 48 pt circle in that accent, its name below, a checkmark and ring when chosen.
private struct AccentSwatch: View {
    let choice: AccentChoice
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: NookSpace.s1) {
                Circle()
                    .fill(choice.color)
                    .frame(width: NookLayout.swatchSize, height: NookLayout.swatchSize)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.nookHeadline)
                                .foregroundStyle(choice.onAccent)
                        }
                    }
                    .background {
                        if isSelected {
                            Circle().strokeBorder(NookColor.textPrimary, lineWidth: 2).padding(-NookSpace.half)
                        }
                    }
                Text(choice.title)
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(choice.title))   // "Terracotta, selected"
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { AppearanceScreen() }.nookAccent(.terracotta)
}
