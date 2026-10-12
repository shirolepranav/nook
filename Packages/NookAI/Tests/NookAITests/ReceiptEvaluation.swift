import Evaluations
import Foundation
import Testing
@testable import NookAI

// P9: the AI receipt reading over every fixture in Fixtures/receipts. Its picks must meet
// Classic's D48 bar (clean all right, damaged 80%), and a warranty is suggested only where
// one is printed. Runs where the on-device model answers (D54); paste the line into the PR.

private let receipts = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appending(path: "../../../../Fixtures/receipts").standardized

struct ReceiptSample: SampleProtocol {
    var input: String           // folder/name, without the extension
    var expected: ReceiptPicks?
}

/// A receipt's total, yyyy-MM-dd date and warranty months: what the fixture's JSON says, and
/// what the AI reading picked.
struct ReceiptPicks: Codable, Sendable {
    var total: String?
    var date: String?
    var warrantyMonths: Int?
}

struct ReceiptEvaluation: Evaluation {
    static let total = Metric("total")
    static let date = Metric("date")
    static let warranty = Metric("warranty")

    let dataset: ArrayLoader<ReceiptSample>

    func subject(from sample: ReceiptSample) async throws -> ModelSubject<ReceiptPicks> {
        let base = receipts.appending(path: sample.input)
        let pdf = base.appendingPathExtension("pdf")
        let document = FileManager.default.fileExists(atPath: pdf.path)
            ? DocumentInput(pdf: pdf)
            : (try? Data(contentsOf: base.appendingPathExtension("jpg"))).flatMap(DocumentInput.init(imageData:))
        guard let document else { throw CocoaError(.fileReadCorruptFile) }
        let reading = try await AIEngine().readReceipt(document)
        let picks = reading.suggested
        return ModelSubject(value: ReceiptPicks(
            total: picks?.amount.map { "\(reading.amounts[$0].value)" },
            date: picks?.date.map { AIEngine.isoDay.string(from: reading.dates[$0].value) },
            warrantyMonths: picks?.warrantyMonths))
    }

    var evaluators: Evaluators {
        Evaluator<ReceiptSample> { sample, subject in
            Self.total.scoring(Self.same(subject.value.total, sample.expected?.total) ? 1.0 : 0.0)
        }
        Evaluator<ReceiptSample> { sample, subject in
            Self.date.scoring(subject.value.date == sample.expected?.date ? 1.0 : 0.0)
        }
        Evaluator<ReceiptSample> { sample, subject in
            Self.warranty.scoring(subject.value.warrantyMonths == sample.expected?.warrantyMonths ? 1.0 : 0.0)
        }
    }

    /// "1348.5" and "1348.50" are the same total.
    static func same(_ picked: String?, _ expected: String?) -> Bool {
        guard let picked, let expected, let a = Decimal(string: picked), let b = Decimal(string: expected) else { return false }
        return a == b
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: Self.total)
        aggregator.computeMean(of: Self.date)
        aggregator.computeMean(of: Self.warranty)
    }
}

private func samples(_ folder: String) throws -> [ReceiptSample] {
    let directory = receipts.appending(path: folder)
    return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map { json in
            ReceiptSample(input: "\(folder)/\(json.deletingPathExtension().lastPathComponent)",
                          expected: try JSONDecoder().decode(ReceiptPicks.self, from: Data(contentsOf: json)))
        }
}

@Test(.enabled("needs a working on-device model", textModelAnswers), arguments: ["clean", "hard"])
func receiptEvaluation(folder: String) async throws {
    let all = try samples(folder)
    let result = try await ReceiptEvaluation(dataset: ArrayLoader(samples: all)).run()
    let total = result.aggregateValue(.mean(of: ReceiptEvaluation.total))
    let date = result.aggregateValue(.mean(of: ReceiptEvaluation.date))
    let warranty = result.aggregateValue(.mean(of: ReceiptEvaluation.warranty))
    let bar = folder == "clean" ? 1.0 : 0.8   // D48
    #expect(total >= bar && date >= bar, "\(folder): totals \(total), dates \(date)")
    #expect(warranty == 1, "a warranty was missed or made up")
    let percent = { (value: Double) in value.formatted(.percent.precision(.fractionLength(0))) }
    print("EVAL receipts/\(folder) \(Date.now.formatted(date: .numeric, time: .omitted)) · "
          + "\(ProcessInfo.processInfo.operatingSystemVersionString) · \(all.count) receipts · "
          + "total \(percent(total)) · date \(percent(date)) · warranty \(percent(warranty))")
}
