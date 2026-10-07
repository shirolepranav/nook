import Foundation
import Testing
@testable import NookKit

private let now = Date(timeIntervalSince1970: 1_790_000_000)

private func item(_ name: String, tags: [String] = [], path: String = "", details: [String] = [],
                  codes: [String] = [], receipt: String = "", isPrivate: Bool = false,
                  confirmed: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> SearchDoc {
    SearchDoc(id: UUID(), kind: .item, name: name, tags: tags, details: details, codes: codes,
              receiptText: receipt, path: path, isPrivate: isPrivate, lastConfirmedAt: confirmed)
}

private func names(_ hits: [SearchHit], in docs: [SearchDoc]) -> [String] {
    hits.map { hit in docs.first { $0.id == hit.id }!.name }
}

private let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

// MARK: Text

@Test func typoDistanceCountsSwapsAsOne() {
    let a = Array("pasport".unicodeScalars), b = Array("passport".unicodeScalars)
    #expect(SearchText.distance(a, b[...], limit: 2) == 1)
    #expect(SearchText.distance(Array("drlil".unicodeScalars), Array("drill".unicodeScalars)[...], limit: 1) == 1)
    #expect(SearchText.distance(Array("abcd".unicodeScalars), Array("wxyz".unicodeScalars)[...], limit: 1) == 2)
}

@Test func foldingIgnoresCaseAccentsAndPunctuation() {
    #expect(SearchText.tokens("Café PRESS, no.2") == ["cafe", "press", "no", "2"])
    #expect(SearchText.compact("SN-4471-AB") == "sn4471ab")
    #expect(SearchText.singular("batteries") == "battery")
    #expect(SearchText.singular("boxes") == "box")
    #expect(SearchText.singular("glass") == "glass")
}

// MARK: Matching

@Test func typosAreForgivenFromFourLetters() {
    let docs = [item("Passport"), item("Drill"), item("Desk lamp")]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("pasport"), in: docs) == ["Passport"])
    #expect(names(index.search("pssport"), in: docs) == ["Passport"])
    #expect(names(index.search("paspo"), in: docs) == ["Passport"])  // a typo in a partial word
    #expect(index.search("drl").isEmpty)                             // 3 letters must be exact
    #expect(SearchIndex(docs: [item("Cast iron skillet")]).search("skis").isEmpty)   // 4: whole words only
}

@Test func partialWordsAccentsAndPluralsMatch() {
    let docs = [item("Café press"), item("AA batteries"), item("Passport")]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("caf"), in: docs) == ["Café press"])
    #expect(names(index.search("CAFE"), in: docs) == ["Café press"])
    #expect(names(index.search("battery"), in: docs) == ["AA batteries"])
    #expect(names(index.search("passports"), in: docs) == ["Passport"])
}

@Test func emojiAndRightToLeftNamesMatch() {
    let docs = [item("🎸 Guitar"), item("مكنسة كهربائية")]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("guit"), in: docs) == ["🎸 Guitar"])
    #expect(names(index.search("مكنسة"), in: docs) == ["مكنسة كهربائية"])
}

@Test func serialsMatchWithOrWithoutSeparators() {
    let docs = [item("Laptop", codes: ["SN-4471-AB"]), item("Kettle")]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("sn4471ab"), in: docs) == ["Laptop"])
    #expect(names(index.search("SN-4471"), in: docs) == ["Laptop"])
}

@Test func synonymsFindOtherWords() {
    let docs = [item("Spare car key"), item("Couch cushion")]
    let index = SearchIndex(docs: docs, synonyms: Synonyms(groups: [["key", "fob"], ["sofa", "couch"]]))
    #expect(names(index.search("fob"), in: docs) == ["Spare car key"])
    #expect(names(index.search("sofa"), in: docs) == ["Couch cushion"])
}

@Test func theShippedSynonymListLoads() {
    let synonyms = Synonyms.load(from: repoRoot.appending(path: "Nook/Resources/synonyms.json"))
    #expect(synonyms.expansions(of: "fob").contains("key"))
    #expect(synonyms.expansions(of: "couch").contains("sofa"))
}

@Test func receiptsDetailsAndPlacesAreSearched() {
    let docs = [item("Dishwasher", receipt: "Best Appliances order 7781"),
                item("Drill", path: "Garage → Workbench"),
                item("Camera", details: ["Fujifilm", "X100"])]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("7781"), in: docs) == ["Dishwasher"])
    #expect(names(index.search("workbench"), in: docs) == ["Drill"])
    #expect(names(index.search("fujifilm"), in: docs) == ["Camera"])
}

@Test func everyWordMustMatchUnlessNothingDoes() {
    let docs = [item("Red mug", path: "Kitchen"), item("Blue mug", path: "Office"), item("Passport")]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("mug kitchen"), in: docs) == ["Red mug"])
    // "passport safe": nothing has both, so the best partial match comes back.
    #expect(names(index.search("passport safe"), in: docs) == ["Passport"])
}

// MARK: Ranking (PRD §9)

@Test func rankingFollowsTheFieldOrder() {
    let docs = [item("Box", receipt: "lamp"),
                item("Chair", path: "Lamp room"),
                item("Tagged", tags: ["lamp"]),
                item("Lamp shade"),
                item("Lamp")]
    let index = SearchIndex(docs: docs, synonyms: Synonyms(groups: [["lamp", "bulb"]]))
    #expect(names(index.search("lamp"), in: docs) == ["Lamp", "Lamp shade", "Tagged", "Chair", "Box"])
    #expect(names(index.search("bulb"), in: docs).first == "Lamp")   // synonym in the name
}

@Test func synonymRanksBelowTagAboveRoom() {
    let docs = [item("Spare key", path: "Hall"), item("Keyring tag thing", tags: ["fob"]),
                item("Coat", path: "Fob room")]
    let index = SearchIndex(docs: docs, synonyms: Synonyms(groups: [["fob", "key"]]))
    #expect(names(index.search("fob"), in: docs) == ["Keyring tag thing", "Spare key", "Coat"])
}

@Test func exactBeatsTypoAndRecentlyConfirmedBreaksTies() {
    let old = Date(timeIntervalSince1970: 1_600_000_000)
    let docs = [item("Pasport case", confirmed: now), item("Passport", confirmed: old), item("Passport cover", confirmed: now)]
    let index = SearchIndex(docs: docs)
    #expect(names(index.search("passport", now: now), in: docs) == ["Passport", "Passport cover", "Pasport case"])
    let twins = [item("Torch", confirmed: old), item("Torch", confirmed: now)]
    #expect(SearchIndex(docs: twins).search("torch", now: now).first?.id == twins[1].id)
}

@Test func privateItemsComeBackFlagged() {
    let docs = [item("Grandma’s ring", isPrivate: true)]
    #expect(SearchIndex(docs: docs).search("ring").first?.isPrivate == true)
}

// MARK: Filters (F-05)

@Test func filtersNarrowItemsAndWorkWithoutText() {
    let garage = UUID()
    var drill = item("Drill"); (drill.roomID, drill.price, drill.currencyCode, drill.isLent) = (garage, 150, "USD", true)
    var euro = item("Kettle"); (euro.price, euro.currencyCode, euro.tags) = (40, "EUR", ["Kitchen"])
    var old = item("Skates", confirmed: Date(timeIntervalSince1970: 1_700_000_000))
    old.warrantyEnd = now.addingTimeInterval(10 * 86_400)
    let room = SearchDoc(id: UUID(), kind: .room, name: "Garage")
    let docs = [drill, euro, old, room]
    let index = SearchIndex(docs: docs)

    var filter = SearchFilter()
    filter.roomIDs = [garage]
    #expect(names(index.search("", filter: filter, now: now), in: docs) == ["Drill"])
    #expect(index.search("garage", filter: filter, now: now).allSatisfy { $0.kind == .item })

    filter = SearchFilter(); filter.minValue = 30
    #expect(names(index.search("", filter: filter, homeCurrency: "USD", now: now), in: docs) == ["Drill"])  // EUR left out (D41)
    filter = SearchFilter(); filter.lentOnly = true
    #expect(names(index.search("", filter: filter, now: now), in: docs) == ["Drill"])
    filter = SearchFilter(); filter.tags = ["kitchen"]
    #expect(names(index.search("", filter: filter, now: now), in: docs) == ["Kettle"])
    filter = SearchFilter(); filter.warranty = .ending
    #expect(names(index.search("", filter: filter, now: now), in: docs) == ["Skates"])
    filter = SearchFilter(); filter.lastSeen = .overTwoYears
    #expect(names(index.search("", filter: filter, now: now), in: docs).sorted() == ["Drill", "Kettle", "Skates"])
    #expect(index.search("", now: now).isEmpty)   // no text, no filter: nothing to show
}

@Test func filtersSurviveBeingSaved() throws {
    var filter = SearchFilter()
    (filter.roomIDs, filter.maxValue, filter.warranty, filter.lastSeen) = ([UUID()], 99.5, .expired, .overOneYear)
    let data = try JSONEncoder().encode(filter)
    #expect(try JSONDecoder().decode(SearchFilter.self, from: data) == filter)
    #expect(filter.count == 4)
}

// MARK: Budget (F5: under 100 ms per keystroke at 5,000 items)

@Test func everyKeystrokeIsUnder100msAt5000Items() throws {
    let common = CommonItem.load(from: repoRoot.appending(path: "Nook/Resources/common-items.json"))
    try #require(!common.isEmpty)
    let rooms = ["Kitchen", "Garage", "Office", "Bedroom", "Living room", "Attic"]
    let docs = (0..<5_000).map { number in
        let entry = common[number % common.count]
        return SearchDoc(id: UUID(), kind: .item, name: "\(entry.name) \(number / common.count + 1)",
                         tags: [entry.category], category: entry.category,
                         details: ["Brand \(number % 40)", "Model \(number)"], codes: ["SN-\(number)-X"],
                         receiptText: number % 5 == 0 ? "Store receipt total \(number) thank you" : "",
                         path: "\(rooms[number % rooms.count]) → Shelf \(number % 12)",
                         lastConfirmedAt: now)
    }
    let clock = ContinuousClock()
    let synonyms = Synonyms.load(from: repoRoot.appending(path: "Nook/Resources/synonyms.json"))
    var index = SearchIndex.empty
    let build = clock.measure { index = SearchIndex(docs: docs, synonyms: synonyms) }
    var slowest = Duration.zero
    for query in ["p", "pa", "pas", "pasp", "paspo", "paspor", "pasport", "drll", "fob", "kitchen shelf 3", "sn-42"] {
        slowest = max(slowest, clock.measure { _ = index.search(query, now: now) })
    }
    print("SearchIndex at 5,000 items: build \(build), slowest keystroke \(slowest)")
    // F5's 100 ms is for the shipped, optimized build on an iPhone 15. Optimized on a Mac it
    // runs ~5 ms, so 25 ms leaves room for the slower phone; ci.sh runs this with `-c release`.
    // An unoptimized test build is ~15× slower and only gets a tripwire.
    #if DEBUG
    #expect(slowest < .milliseconds(250))
    #else
    #expect(slowest < .milliseconds(25))
    #endif
}
