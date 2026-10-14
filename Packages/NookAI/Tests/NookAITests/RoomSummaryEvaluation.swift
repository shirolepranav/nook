import Evaluations
import Foundation
import Testing
@testable import NookAI

// 05 §4: R-02's room summaries (D56). Ten rooms; the model writes a paragraph for each, and
// the router's grounding check decides whether it would be shown. Pass: at least 7 of 10
// grounded. An ungrounded one is never shown, so a miss costs a blank field, not a wrong
// report. Needs a real device (D54).

private let rooms: [RoomFacts] = [
    .init(room: "Kitchen", things: [.init(name: "Espresso machine", category: "Appliances"), .init(name: "Stand mixer", category: "Appliances"),
                                    .init(name: "Dutch oven", category: "Kitchen"), .init(name: "Blender", category: "Appliances")],
          totals: [(1_578, "USD")]),
    .init(room: "Garage", things: [.init(name: "Cordless drill", category: "Tools"), .init(name: "Camping tent", category: "Sports"),
                                   .init(name: "Bike pump", category: "Sports")], totals: [(514, "USD")]),
    .init(room: "Office", things: [.init(name: "Laptop", category: "Electronics"), .init(name: "Monitor", quantity: 2, category: "Electronics"),
                                   .init(name: "Desk chair", category: "Furniture")], totals: [(3_120, "USD")]),
    .init(room: "Bedroom", things: [.init(name: "Winter coat", category: "Clothing"), .init(name: "Jewelry box", category: "Jewelry")],
          totals: [(2_040, "USD")]),
    .init(room: "Living room", things: [.init(name: "Record player", category: "Electronics"), .init(name: "Sofa", category: "Furniture"),
                                        .init(name: "Board games", quantity: 6, category: "Kids & Baby")], totals: [(1_899, "USD")]),
    .init(room: "Nursery", things: [.init(name: "Crib", category: "Kids & Baby"), .init(name: "Baby monitor", category: "Electronics")],
          totals: [(610, "USD")]),
    .init(room: "Bathroom", things: [.init(name: "Hair dryer", category: "Appliances"), .init(name: "Towels", quantity: 8, category: "Linens")],
          totals: []),
    .init(room: "Attic", things: [.init(name: "Christmas lights", quantity: 4, category: "Other"), .init(name: "Suitcase", quantity: 2, category: "Other")],
          totals: [(240, "USD")]),
    .init(room: "Studio", things: [.init(name: "Acoustic guitar", category: "Music"), .init(name: "Keyboard", category: "Music"),
                                   .init(name: "Microphone", category: "Electronics")], totals: [(1_450, "EUR")]),
    .init(room: "Shed", things: [.init(name: "Lawn mower", category: "Tools"), .init(name: "Hedge trimmer", category: "Tools")],
          totals: [(780, "USD")]),
]

struct RoomSummarySample: SampleProtocol {
    var input: Int
    var expected: Bool?
}

struct RoomSummaryEvaluation: Evaluation {
    static let grounded = Metric("grounded")

    let dataset: ArrayLoader<RoomSummarySample>
    let engine = AIEngine()

    func subject(from sample: RoomSummarySample) async throws -> ModelSubject<Bool> {
        let text = try await engine.summarizeRoom(rooms[sample.input]) ?? ""
        return ModelSubject(value: RoomSummary.grounded(text, in: rooms[sample.input]) != nil)
    }

    var evaluators: Evaluators {
        Evaluator<RoomSummarySample> { _, subject in Self.grounded.scoring(subject.value ? 1.0 : 0.0) }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: Self.grounded)
    }
}

@Test(.enabled("needs a working on-device model", textModelAnswers))
func roomSummaryEvaluation() async throws {
    let samples = rooms.indices.map { RoomSummarySample(input: $0, expected: true) }
    let result = try await RoomSummaryEvaluation(dataset: ArrayLoader(samples: samples)).run()
    let grounded = result.aggregateValue(.mean(of: RoomSummaryEvaluation.grounded))
    #expect(grounded >= 0.7, "only \(grounded) of the summaries were grounded")
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    print("EVAL room-summary \(Date.now.formatted(date: .numeric, time: .omitted)) · \(os) · 10 rooms · "
          + "grounded \(grounded.formatted(.percent.precision(.fractionLength(0))))")
}
