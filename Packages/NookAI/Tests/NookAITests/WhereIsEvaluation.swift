import Evaluations
import Foundation
import FoundationModels
import NookKit
import SwiftData
import Testing
@testable import NookAI

// 05 §4: the "Where is…?" evaluation. 30 questions over a seeded home (`Fixtures/eval/where-is.json`):
// 20 answerable, 5 about things never saved (one of them Private), 5 move statements. Each runs
// as Find runs it: the router reads it, falling back to Classic, and FindService answers from
// records. Pass: zero invented locations, and every move statement a proposal that writes
// nothing (PRD §6). The AI run needs a real device (D54); the Classic run checks the same
// guarantees everywhere, CI included.

private let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appending(path: "../../../../Fixtures").standardized
private let seedURL = fixtures.appending(path: "eval/where-is.json")

struct WhereIsSeed: Decodable {
    struct Room: Decodable { var name: String; var spots: [String]; var boxes: [Box]? }
    struct Box: Decodable { var name: String; var on: String; var packed: String? }
    struct Thing: Decodable {
        var name: String, room: String
        var spot: String?, lentTo: String?, quantity: Int?, `private`: Bool?
    }
    struct Question: Decodable { var q: String; var expect: String }

    var rooms: [Room]
    var items: [Thing]
    var questions: [Question]

    static func load() throws -> WhereIsSeed { try JSONDecoder().decode(Self.self, from: Data(contentsOf: seedURL)) }
}

/// The seeded home, and what Find shows for a question in it.
@MainActor final class SeededHome {
    let container: ModelContainer
    let index: SearchIndex
    private let names: [UUID: String]

    init(_ seed: WhereIsSeed) throws {
        container = try NookStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let rooms = RoomService(context: context)
        var places: [String: Location] = [:]
        for room in seed.rooms {
            let made = try rooms.addRoom(named: room.name)
            places[room.name] = Location(room: made)
            for name in room.spots { places[name] = Location(room: made, spot: try rooms.addSpot(named: name, in: made)) }
            for box in room.boxes ?? [] {
                let made = try rooms.addContainer(named: box.name, in: made, inside: places[box.on]?.spot)
                made.packedAt = box.packed.flatMap { AIEngine.isoDay.date(from: $0) }
                places[box.name] = Location(room: made.room!, spot: made)
            }
        }
        for thing in seed.items {
            var draft = ItemDraft(currencyCode: "USD", location: places[thing.spot ?? thing.room])
            (draft.name, draft.quantity, draft.isPrivate) = (thing.name, thing.quantity ?? 1, thing.private ?? false)
            let item = try ItemService(context: context).create(draft)
            if let person = thing.lentTo {
                let loan = Loan(personName: person)
                context.insert(loan)
                loan.item = item
            }
        }
        try context.save()
        let synonyms = Synonyms.load(from: fixtures.appending(path: "../Nook/Resources/synonyms.json").standardized)
        let docs = SearchSnapshot.docs(in: ModelContext(container))
        index = SearchIndex(docs: docs, synonyms: synonyms)
        names = Dictionary(docs.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// "item:Passports", "place:Garage", "choose", "move:Passports→Safe" or "none", as Find
    /// would show it (FindScreen.search).
    func outcome(of question: FindQuestion) -> String {
        let find = FindService(context: container.mainContext)
        let hits = index.search(terms: question.terms)
        if question.intent == .move,
           let move = find.proposedMove(itemHits: hits, placeHits: index.search(terms: question.placeTerms)) {
            return "move:\(names[move.item] ?? "?")→\(move.to.spot?.name ?? move.to.room.name)"
        }
        switch find.answer(question, hits: hits) {
        case nil: return "none"
        case .choose: return "choose"
        case .contents(let place, _, _): return "place:\(names[place] ?? "?")"
        case let answer?: return answer.itemID.flatMap { names[$0] }.map { "item:\($0)" } ?? "none"
        }
    }

    /// Every item's place, to prove nothing moved.
    var locations: [String] {
        ((try? container.mainContext.fetch(FetchDescriptor<Item>())) ?? []).map { "\($0.name)@\(Location(of: $0)?.path ?? "")" }.sorted()
    }
}

struct WhereIsSample: SampleProtocol {
    var input: String
    var expected: String?
}

struct WhereIsEvaluation: Evaluation {
    static let correct = Metric("correct")
    /// An answer for something never saved: must stay 0.
    static let invented = Metric("invented")

    let dataset: ArrayLoader<WhereIsSample>
    let home: SeededHome
    let router: CapabilityRouter

    func subject(from sample: WhereIsSample) async throws -> ModelSubject<String> {
        let question = await router.understand(sample.input, index: home.index)
        return ModelSubject(value: await home.outcome(of: question))
    }

    var evaluators: Evaluators {
        Evaluator<WhereIsSample> { sample, subject in
            Self.correct.scoring(subject.value == sample.expected ? 1.0 : 0.0)
        }
        Evaluator<WhereIsSample> { sample, subject in
            Self.invented.scoring(sample.expected == "none" && subject.value != "none" && subject.value != "choose" ? 1.0 : 0.0)
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: Self.correct)
        aggregator.computeMean(of: Self.invented)
    }
}

@MainActor private func run(_ router: CapabilityRouter) async throws -> (correct: Double, invented: Double, moves: [String], wrote: Bool) {
    let seed = try WhereIsSeed.load()
    let home = try SeededHome(seed)
    let before = home.locations
    let samples = seed.questions.map { WhereIsSample(input: $0.q, expected: $0.expect) }
    let result = try await WhereIsEvaluation(dataset: ArrayLoader(samples: samples), home: home, router: router).run()
    #expect(result.errors.inferenceFailureCount == 0, "\(result.errors.inferenceFailureCount) questions weren't read")
    var moves: [String] = []
    for question in seed.questions where question.expect.hasPrefix("move:") {
        moves.append(home.outcome(of: await router.understand(question.q, index: home.index)))
    }
    return (result.aggregateValue(.mean(of: WhereIsEvaluation.correct)),
            result.aggregateValue(.mean(of: WhereIsEvaluation.invented)), moves, home.locations != before)
}

/// Like the room scan's probe (D54), without needing image input.
@Sendable func textModelAnswers() async -> Bool {
    guard SystemLanguageModel.default.availability == .available else { return false }
    return (try? await LanguageModelSession().respond(to: "Reply with OK.")) != nil
}

@Test(.enabled("needs a working on-device model", textModelAnswers))
func whereIsEvaluation() async throws {
    let outcome = try await run(CapabilityRouter(ai: AIEngine(), classic: ClassicEngine()) {
        Availability(usesAI: true, seesImages: false)
    })
    #expect(outcome.invented == 0, "answered for something never saved")
    #expect(outcome.moves.allSatisfy { $0.hasPrefix("move:") }, "move statements read as \(outcome.moves)")
    #expect(!outcome.wrote, "a question moved something")
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    // 05 §4: run date · iOS build · device · recall · precision · notes
    print("EVAL where-is \(Date.now.formatted(date: .numeric, time: .omitted)) · \(os) · 30 questions · "
          + "correct \(outcome.correct.formatted(.percent.precision(.fractionLength(0)))) · invented 0 · "
          + "moves proposed \(outcome.moves.filter { $0.hasPrefix("move:") }.count)/5")
}

// The same questions read the Classic way: never invented, never a move, never a write.
@Test func whereIsClassicNeverInventsOrMoves() async throws {
    let outcome = try await run(CapabilityRouter(ai: ClassicEngine(), classic: ClassicEngine()) { .classic })
    #expect(outcome.invented == 0)
    #expect(outcome.moves.allSatisfy { !$0.hasPrefix("move:") })
    #expect(!outcome.wrote)
    #expect(outcome.correct >= 0.5, "Classic got \(outcome.correct)")
}
