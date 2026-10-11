import CoreGraphics
import Evaluations
import Foundation
import FoundationModels
import ImageIO
import Testing
@testable import NookAI

// 05 §4: the room-scan evaluation. Each photo in `Fixtures/eval` has the items a person sees in
// it (`labels.json`); the model's suggestions are scored for recall (labels found ÷ labels) and
// precision (correct ÷ suggested). Runs only where the on-device model can see images, so a Mac
// or iPhone with Apple Intelligence; elsewhere it skips. Paste the printed line into the PR.

private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../..").standardized
private let evalFolder = repo.appending(path: "Fixtures/eval")

/// One labeled photo from `labels.json`.
struct ScanSample: SampleProtocol {
    var input: String          // the photo's file name
    var expected: [String]?    // what a person sees in it
}

/// Whether a suggestion names a labeled item: "the synonym list counts" (05 §4).
struct NameMatcher {
    let groups: [[String]]

    static let shared: NameMatcher = {
        let url = repo.appending(path: "Nook/Resources/synonyms.json")
        let groups = (try? JSONDecoder().decode([[String]].self, from: Data(contentsOf: url))) ?? []
        return NameMatcher(groups: groups)
    }()

    /// Lowercased words, without plurals' trailing "s".
    private func words(_ name: String) -> Set<String> {
        Set(name.lowercased().split { !$0.isLetter && !$0.isNumber }.map { word in
            word.count > 3 && word.hasSuffix("s") ? String(word.dropLast()) : String(word)
        })
    }

    /// Words plus every synonym of each.
    private func expanded(_ name: String) -> Set<String> {
        var all = words(name)
        for group in groups where !all.isDisjoint(with: group.flatMap { words($0) }) {
            all.formUnion(group.flatMap { words($0) })
        }
        return all
    }

    /// "Electric kettle" matches "Kettle"; "Couch" matches "Sofa". The label's head word (its
    /// last, as in "coffee machine") has to be there.
    func matches(_ suggestion: String, _ label: String) -> Bool {
        let head = label.lowercased().split(separator: " ").last.map { String($0) } ?? label
        return !expanded(head).isDisjoint(with: expanded(suggestion))
    }

    /// Recall and precision for one photo. Each label can be found once.
    func score(suggested: [String], labels: [String]) -> (recall: Double, precision: Double) {
        var unmatched = labels
        var correct = 0
        for name in suggested {
            if let index = unmatched.firstIndex(where: { matches(name, $0) }) {
                unmatched.remove(at: index)
                correct += 1
            }
        }
        let recall = labels.isEmpty ? 1 : Double(correct) / Double(labels.count)
        let precision = suggested.isEmpty ? (labels.isEmpty ? 1 : 0) : Double(correct) / Double(suggested.count)
        return (recall, precision)
    }
}

struct RoomScanEvaluation: Evaluation {
    static let recall = Metric("recall")
    static let precision = Metric("precision")

    let dataset: ArrayLoader<ScanSample>

    func subject(from sample: ScanSample) async throws -> ModelSubject<[String]> {
        let url = evalFolder.appending(path: sample.input)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
        var names: [String] = []
        for try await item in AIEngine().detectItems(in: PhotoInput(image: image)) { names.append(item.name) }
        return ModelSubject(value: names)
    }

    var evaluators: Evaluators {
        Evaluator<ScanSample> { sample, subject in
            Self.recall.scoring(NameMatcher.shared.score(suggested: subject.value, labels: sample.expected ?? []).recall)
        }
        Evaluator<ScanSample> { sample, subject in
            Self.precision.scoring(NameMatcher.shared.score(suggested: subject.value, labels: sample.expected ?? []).precision)
        }
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: Self.recall)
        aggregator.computeMean(of: Self.precision)
    }
}

private struct Label: Decodable {
    var file: String
    var items: [String]
}

private var canRun: Bool {
    let model = SystemLanguageModel.default
    return model.availability == .available && model.capabilities.contains(.vision)
        && FileManager.default.fileExists(atPath: evalFolder.appending(path: "labels.json").path)
}

@Test(.enabled(if: canRun, "needs Apple Intelligence with image input and Fixtures/eval/labels.json"))
func roomScanEvaluation() async throws {
    let labels = try JSONDecoder().decode([Label].self, from: Data(contentsOf: evalFolder.appending(path: "labels.json")))
    let evaluation = RoomScanEvaluation(dataset: ArrayLoader(samples: labels.map { ScanSample(input: $0.file, expected: $0.items) }))
    let result = try await evaluation.run()
    let recall = result.aggregateValue(.mean(of: RoomScanEvaluation.recall))
    let precision = result.aggregateValue(.mean(of: RoomScanEvaluation.precision))
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    // 05 §4: run date · iOS build · device · recall · precision · notes
    print("EVAL \(Date.now.formatted(date: .numeric, time: .omitted)) · \(os) · \(labels.count) photos · "
          + "recall \(recall.formatted(.percent.precision(.fractionLength(0)))) · "
          + "precision \(precision.formatted(.percent.precision(.fractionLength(0))))")
    try? result.saveJSON(to: URL.temporaryDirectory)
}

// The scoring itself runs everywhere, CI included.
@Test func nameMatchingCountsSynonymsAndPlurals() {
    let matcher = NameMatcher(groups: [["sofa", "couch", "settee"], ["tv", "television"]])
    #expect(matcher.matches("Electric kettle", "Kettle"))
    #expect(matcher.matches("Couch", "Sofa"))
    #expect(matcher.matches("Television", "TV"))
    #expect(matcher.matches("Books", "Book"))
    #expect(!matcher.matches("Kettlebell", "Kettle"))
    #expect(!matcher.matches("Coffee mug", "Coffee machine"))
    let score = matcher.score(suggested: ["Kettle", "Kettle", "Lamp", "Toaster"], labels: ["Kettle", "Toaster", "Blender"])
    #expect(score.recall == 2.0 / 3 && score.precision == 0.5)
}
