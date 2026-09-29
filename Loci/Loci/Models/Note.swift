import Foundation
import SwiftData

extension LociSchemaV1 {
    /// One concept. All text is plain for now; Markdown and LaTeX rendering come in milestone 2.
    @Model
    final class Note {
        var id: UUID = UUID()
        var title: String = ""
        /// The key formula or definition (LaTeX), shown on graph nodes and in lists.
        var statement: String = ""
        /// Markdown + LaTeX.
        var body: String = ""
        /// Where the idea comes from, e.g. "Rice §3.5".
        var citation: String = ""
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// Set when the note is in Recently Deleted.
        var deletedAt: Date?
        /// Saved graph layout position; nil until the note has been placed.
        var graphX: Double?
        var graphY: Double?

        var folder: Folder?

        @Relationship(inverse: \Tag.notes)
        var tags: [Tag]? = []

        @Relationship(deleteRule: .cascade, inverse: \NoteLink.source)
        var outgoing: [NoteLink]? = []

        @Relationship(deleteRule: .cascade, inverse: \NoteLink.target)
        var incoming: [NoteLink]? = []

        init(title: String = "", body: String = "") {
            self.title = title
            self.body = body
        }
    }
}

extension Note {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// The line list rows show under the title: the key statement if there is one, otherwise
    /// the first non-blank line of the body.
    var summary: String {
        let statement = self.statement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !statement.isEmpty {
            return statement
        }
        return body.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    /// Whether this note is listed in Recently Deleted: it was deleted itself, rather than along
    /// with its folder.
    var appearsInRecentlyDeleted: Bool {
        deletedAt != nil && folder?.deletedAt == nil
    }
}
