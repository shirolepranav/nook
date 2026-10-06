import Testing
@testable import NookKit

@Test func questionsBecomeSearchWordsAndAnIntent() {
    #expect(FindQuestion("Where are the passports?") == FindQuestion(intent: .locate, terms: ["passports"]))
    #expect(FindQuestion("Where’s the winter bedding?").terms == ["winter", "bedding"])
    #expect(FindQuestion("Who has my drill?") == FindQuestion(intent: .who, terms: ["drill"]))
    #expect(FindQuestion("What’s in the garage?") == FindQuestion(intent: .contents, terms: ["garage"]))
    #expect(FindQuestion("Do I have any AA batteries?") == FindQuestion(intent: .quantity, terms: ["aa", "batteries"]))
}

@Test func plainSearchesAndSentencesKeepTheirWords() {
    #expect(FindQuestion("hdmi cable") == FindQuestion(intent: .locate, terms: ["hdmi", "cable"]))
    // Classic F-04: "I put X in Y" is just a search (01 F-04).
    #expect(FindQuestion("I put the passports in the safe").terms == ["passports", "safe"])
    // Only small words: search for them anyway.
    #expect(FindQuestion("in").terms == ["in"])
}
