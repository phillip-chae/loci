import Foundation
import SwiftData

extension LociSchemaV1 {
    /// One level of a nested tag such as `probability/random-variables/independence`.
    /// Part of the v1 schema now; tags get UI in milestone 3.
    @Model
    final class Tag {
        var id: UUID = UUID()
        /// One path segment, e.g. "independence". The full path comes from the parents.
        var name: String = ""
        var colorHex: String?

        var parent: Tag?

        @Relationship(deleteRule: .cascade, inverse: \Tag.parent)
        var children: [Tag]? = []

        var notes: [Note]? = []

        init(name: String) {
            self.name = name
        }
    }
}
