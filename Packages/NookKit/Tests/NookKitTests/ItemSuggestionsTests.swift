import Testing
@testable import NookKit

private let common = [CommonItem(name: "Espresso machine", category: "Appliances"),
                      CommonItem(name: "Café press", category: "Kitchen"),
                      CommonItem(name: "Electric drill", category: "Tools")]

@Test func suggestionsStartAtTheFirstLetterAndMatchAnyWord() {
    #expect(ItemSuggestions.suggestions(for: "e", past: [], common: common) == ["Espresso machine", "Electric drill"])
    #expect(ItemSuggestions.suggestions(for: "drill", past: [], common: common) == ["Electric drill"])
    #expect(ItemSuggestions.suggestions(for: " ", past: [], common: common).isEmpty)
}

@Test func suggestionsIgnoreCaseAndAccents() {
    #expect(ItemSuggestions.suggestions(for: "CAFE", past: [], common: common) == ["Café press"])
}

@Test func pastNamesComeFirstWithoutDuplicates() {
    let past = ["espresso machine", "Espresso cups"]
    #expect(ItemSuggestions.suggestions(for: "esp", past: past, common: common) == ["espresso machine", "Espresso cups"])
}

@Test func emojiAndRightToLeftNamesWork() {
    let past = ["🎸 Guitar", "مكنسة كهربائية"]
    #expect(ItemSuggestions.suggestions(for: "gui", past: past, common: []) == ["🎸 Guitar"])
    #expect(ItemSuggestions.suggestions(for: "مكن", past: past, common: []) == ["مكنسة كهربائية"])
}

@Test func commonItemsFillAnEmptyCategory() {
    #expect(ItemSuggestions.category(for: "espresso Machine", in: common) == "Appliances")
    #expect(ItemSuggestions.category(for: "Rocket", in: common) == nil)
}
