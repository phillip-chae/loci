import Foundation
import SwiftData

extension LociSchemaV1 {
    /// A typed link from one note to another. Not called `Link`, because SwiftUI already has a
    /// `Link` view. Part of the v1 schema now; links get UI in milestone 4.
    @Model
    final class NoteLink {
        var id: UUID = UUID()
        var kindRaw: String = "related"
        /// Optional LaTeX relating the two notes, e.g. `f_X(x) = F_X'(x)`.
        var label: String = ""
        var originRaw: String = "manual"
        var createdAt: Date = Date.now

        var source: Note?
        var target: Note?

        init(kind: LinkKind = .related, label: String = "", origin: LinkOrigin = .manual) {
            self.kindRaw = kind.rawValue
            self.label = label
            self.originRaw = origin.rawValue
        }
    }
}

/// How a link's source relates to its target. See docs/ARCHITECTURE.md §3 for each kind's meaning.
/// Stored as a raw string, so kinds can be added without a schema change.
enum LinkKind: String, CaseIterable, Identifiable {
    case computes, generalizes, prerequisite, contrasts, related

    var id: Self { self }
}

/// What created a link.
enum LinkOrigin: String {
    case manual, wikilink, suggestion
}

extension NoteLink {
    /// Unknown raw values, e.g. a kind added by a newer version of the app on another device,
    /// read as `.related` without overwriting what is stored.
    var kind: LinkKind {
        get { LinkKind(rawValue: kindRaw) ?? .related }
        set { kindRaw = newValue.rawValue }
    }

    var origin: LinkOrigin {
        get { LinkOrigin(rawValue: originRaw) ?? .manual }
        set { originRaw = newValue.rawValue }
    }
}
