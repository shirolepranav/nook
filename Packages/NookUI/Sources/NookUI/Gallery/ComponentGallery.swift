import SwiftUI

/// Every NookUI component in every state, for design QA (03 §15): check it in light, dark,
/// Increase Contrast, Reduce Transparency, every Liquid Glass setting and every text size.
/// Reached from Settings → Components in debug builds. Sample copy is verbatim on purpose.
public struct ComponentGallery: View {
    @State private var chip = true
    @State private var room = false
    @State private var name = ""
    @State private var toast: ToastMessage?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s4) {
                section("Type") {
                    Text(verbatim: "Display").font(.nookDisplay)
                    Text(verbatim: "Title").font(.nookTitle)
                    Text(verbatim: "Section").font(.nookSection)
                    Text(verbatim: "Headline").font(.nookHeadline)
                    Text(verbatim: "Body").font(.nookBody)
                    Text(verbatim: "Kitchen → Top shelf").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                    MoneyText(4380, currencyCode: "USD", font: .nookTotal)
                }
                section("Buttons") {
                    Button("Save") {}.buttonStyle(.nookPrimary)
                    Button("Add spot") {}.buttonStyle(.nookSecondary)
                    Button("Cancel") {}.buttonStyle(.nookTertiary)
                    Button("Delete") {}.buttonStyle(.nookDestructive)
                    Button("Unlock Pro") {}.buttonStyle(.nookPrimary).disabled(true)
                    Button("Save All") {}.buttonStyle(NookButtonStyle(.primary, isLoading: true))
                }
                section("Chips") {
                    FilterChip(verbatim: "Garage", isSelected: chip) { chip.toggle() }
                    RoomChip(name: "Office", symbol: "desktopcomputer", color: .sky, isSelected: room) { room.toggle() }
                }
                section("Status") {
                    StatusPill(.active, Text(verbatim: "Active until 2027"))
                    StatusPill(.endingSoon, Text(verbatim: "Ends in 12 days"))
                    StatusPill(.expired, Text(verbatim: "Expired Mar 3"))
                    StatusPill(.lent, Text(verbatim: "Lent to Jordan"))
                    HStack { CardBadge(.privateItem); CardBadge(.lent); CardBadge(.endingSoon) }
                }
                section("Fields") {
                    NookTextField(Text(verbatim: "Name"), text: $name, prompt: Text(verbatim: "Coffee machine"),
                                  helper: Text(verbatim: "Tap to type."))
                    NookTextField(Text(verbatim: "Price"), text: .constant("12,50,0"),
                                  error: Text(verbatim: "That doesn't look like a price."))
                }
                section("Cards") {
                    NookGrid {
                        PhotoCard(name: "Headphones", location: "Office → Desk",
                                  value: (249, "USD"))
                        PhotoCard(name: "Passport", location: "Bedroom → Wardrobe", badges: [.privateItem])
                        RoomCard(name: "Kitchen", symbol: "fork.knife", color: .butter, itemCount: 48)
                        AddCard(Text(verbatim: "Add room"))
                    }
                }
                section("States") {
                    EmptyStateView(.shelfWaiting, title: Text(verbatim: "Let’s start with one room."),
                                   message: Text(verbatim: "Scan a shelf and tag what’s on it."))
                    ErrorStateView(title: Text(verbatim: "Your rooms didn’t load"),
                                   message: Text(verbatim: "Your items are safe on this iPhone.")) {}
                    SkeletonCard().frame(maxWidth: NookLayout.cardMinWidth)
                    Button(String("Show a toast")) {
                        toast = ToastMessage("Moved to Kitchen → Pantry.") {}
                    }
                    .buttonStyle(.nookSecondary)
                }
                section("Capture") {
                    HStack(spacing: NookSpace.s4) {
                        CaptureButton {}
                        CaptureButton(showsGlow: true) {}
                    }
                    .padding(NookSpace.s1)
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .toast($toast)
        .navigationTitle(Text(verbatim: "Components"))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Text(verbatim: title)
                .font(.nookSection)
                .foregroundStyle(NookColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

#Preview("Light") { NavigationStack { ComponentGallery() }.nookAccent(.terracotta) }
#Preview("Dark") { NavigationStack { ComponentGallery() }.nookAccent(.sage).preferredColorScheme(.dark) }
#Preview("AX5") {
    NavigationStack { ComponentGallery() }.nookAccent(.terracotta).dynamicTypeSize(.accessibility5)
}
