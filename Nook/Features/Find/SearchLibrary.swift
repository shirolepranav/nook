import SwiftUI
import SwiftData
import NookKit

/// The live search index (04 §6, D46). Built after launch on a background context, then
/// rebuilt shortly after each save, so Find always searches what's in the store. Searching
/// copies the immutable index and runs off the main actor.
@Observable @MainActor
final class SearchLibrary {
    private(set) var index = SearchIndex.empty
    private(set) var isReady = false
    /// Goes up with each rebuild, so an open search runs again on fresh data.
    private(set) var version = 0
    /// Items in the store, for Find's empty state.
    private(set) var itemCount = 0
    /// The most recently confirmed non-private item, for Find's "Try asking" (F-01).
    private(set) var exampleName: String?
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private var pending: Task<Void, Never>?

    nonisolated static let synonyms = Synonyms.load(from: Bundle.main.url(forResource: "synonyms", withExtension: "json"))

    init(container: ModelContainer) {
        self.container = container
    }

    /// Run from the shell's `.task`: builds now, then again after every save.
    func keepCurrent() async {
        await rebuild()
        for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
            pending?.cancel()
            pending = Task {
                // Several saves in a row (a multi-item move, an import) cost one rebuild.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await rebuild()
            }
        }
    }

    // ponytail: rebuilds everything on each save (~70 ms at 5,000 items, optimized); make it
    // incremental if that grows past ~300 ms.
    private func rebuild() async {
        let container = container
        index = await Task.detached(priority: .userInitiated) {
            SearchIndex(docs: SearchSnapshot.docs(in: ModelContext(container)), synonyms: Self.synonyms)
        }.value
        let items = index.docs.filter { $0.kind == .item }
        itemCount = items.count
        exampleName = items.filter { !$0.isPrivate }.max { $0.lastConfirmedAt < $1.lastConfirmedAt }?.name
        isReady = true
        version += 1
    }

    /// Ranked hits for what was typed, with the filters.
    func search(_ question: FindQuestion, filter: SearchFilter) async -> [SearchHit] {
        let (index, currency) = (index, HomeCurrency.code)
        return await Task.detached(priority: .userInitiated) {
            index.search(terms: question.terms, filter: filter, homeCurrency: currency)
        }.value
    }

    /// How many things a search finds: saved-search counts, quick-filter chips and
    /// "Show N Items" (F-05, F-06).
    func count(_ question: FindQuestion = FindQuestion(""), filter: SearchFilter) -> Int {
        index.search(terms: question.terms, filter: filter, homeCurrency: HomeCurrency.code, limit: .max).count
    }
}

extension EnvironmentValues {
    @Entry var searchLibrary: SearchLibrary?
}
