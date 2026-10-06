import Foundation
import SwiftData

extension NookSchemaV1 {
    /// A named search pinned on Find (F-06): the words and the filters. A model rather than
    /// a preference, so saved searches sync with everything else in P11 (D46).
    @Model
    public final class SavedSearch {
        public var id: UUID = UUID()
        public var name: String = ""
        public var query: String = ""
        /// A JSON `SearchFilter`; nil when there are no filters.
        public var filterData: Data?
        /// Position on Find; relationships can't be ordered in CloudKit (D8).
        public var order: Int = 0
        public var createdAt: Date = Date.now

        public var filter: SearchFilter {
            get { filterData.flatMap { try? JSONDecoder().decode(SearchFilter.self, from: $0) } ?? SearchFilter() }
            set { filterData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
        }

        public init(name: String, query: String, filter: SearchFilter, order: Int) {
            self.name = name
            self.query = query
            self.order = order
            self.filter = filter
        }
    }
}
