import Foundation
import SwiftData

extension LociSchemaV1 {
    /// A folder in the library. A "notebook" is just a top-level folder, and folders nest to any depth.
    @Model
    final class Folder {
        /// Stable identity that survives saves and sync, unlike `persistentModelID` on a new object.
        var id: UUID = UUID()
        var name: String = ""
        /// To-many relationships are unordered, so manual ordering needs this. Unused until
        /// folders can be reordered; the sidebar sorts by name for now.
        var sortIndex: Double = 0
        var createdAt: Date = Date.now
        /// Set when the folder is in Recently Deleted.
        var deletedAt: Date?

        var parent: Folder?

        @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
        var children: [Folder]? = []

        @Relationship(deleteRule: .cascade, inverse: \Note.folder)
        var notes: [Note]? = []

        init(name: String) {
            self.name = name
        }
    }
}

extension Folder {
    /// Sorts folders the way Finder does: case-insensitive, with numbers in numeric order.
    static func byName(_ lhs: Folder, _ rhs: Folder) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// Subfolders that aren't in Recently Deleted, sorted by name.
    var sortedChildren: [Folder] {
        liveChildren.sorted(by: Folder.byName)
    }

    /// Whether `other` is this folder or sits anywhere beneath it.
    func isAncestor(of other: Folder) -> Bool {
        var current: Folder? = other
        while let folder = current {
            if folder === self { return true }
            current = folder.parent
        }
        return false
    }

    /// How many subfolders and notes sit beneath this folder at every depth, not counting
    /// anything in Recently Deleted.
    var descendantCounts: (folders: Int, notes: Int) {
        var folders = 0
        var notes = (self.notes ?? []).filter { $0.deletedAt == nil }.count
        for child in liveChildren {
            let counts = child.descendantCounts
            folders += 1 + counts.folders
            notes += counts.notes
        }
        return (folders, notes)
    }

    /// Whether this folder is listed in Recently Deleted: it was deleted itself, rather than
    /// along with a deleted parent.
    var appearsInRecentlyDeleted: Bool {
        deletedAt != nil && parent?.deletedAt == nil
    }

    private var liveChildren: [Folder] {
        (children ?? []).filter { $0.deletedAt == nil }
    }
}
