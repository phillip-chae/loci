import Foundation
import SwiftData
import Testing
@testable import Loci

@MainActor
struct LibraryTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Whole seconds, so values survive the rounding `trashFolder` and `trashNote` apply.
    private let t1 = Date(timeIntervalSinceReferenceDate: 1_000)
    private let t2 = Date(timeIntervalSinceReferenceDate: 2_000)

    init() throws {
        container = try ModelContainer.loci(inMemory: true)
    }

    // MARK: Creating

    @Test func createsNestedFolders() throws {
        let math = context.createFolder(named: "Math")
        let probability = context.createFolder(named: "Probability", in: math)
        let randomVariables = context.createFolder(named: "Random Variables", in: probability)

        #expect(randomVariables.parent?.id == probability.id)
        #expect(probability.parent?.id == math.id)
        #expect(math.sortedChildren.map(\.name) == ["Probability"])

        let roots = try context.fetch(FetchDescriptor<Folder>(predicate: #Predicate<Folder> { $0.parent == nil }))
        #expect(roots.map(\.name) == ["Math"])
    }

    @Test func sortsSubfoldersByName() {
        let parent = context.createFolder(named: "Parent")
        for name in ["beta", "Alpha", "Chapter 10", "Chapter 2"] {
            context.createFolder(named: name, in: parent)
        }

        #expect(parent.sortedChildren.map(\.name) == ["Alpha", "beta", "Chapter 2", "Chapter 10"])
    }

    @Test func createsNoteInFolder() throws {
        let folder = context.createFolder(named: "Probability")
        let note = context.createNote(in: folder)

        #expect(note.folder?.id == folder.id)
        #expect(folder.notes?.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
    }

    // MARK: Recently Deleted

    @Test func trashingFolderMovesEverythingBeneathIt() throws {
        let math = context.createFolder(named: "Math")
        let probability = context.createFolder(named: "Probability", in: math)
        let note = context.createNote(in: probability)
        let history = context.createFolder(named: "History")

        context.trashFolder(math, at: t1)

        #expect(math.deletedAt == t1)
        #expect(probability.deletedAt == t1)
        #expect(note.deletedAt == t1)
        #expect(history.deletedAt == nil)

        // Only the folder that was deleted directly is listed in Recently Deleted.
        #expect(math.appearsInRecentlyDeleted)
        #expect(!probability.appearsInRecentlyDeleted)
        #expect(!note.appearsInRecentlyDeleted)

        let liveRoots = try context.fetch(FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { $0.parent == nil && $0.deletedAt == nil }
        ))
        #expect(liveRoots.map(\.name) == ["History"])
    }

    @Test func trashedItemsAreLeftOutOfTreeAndCounts() {
        let math = context.createFolder(named: "Math")
        let algebra = context.createFolder(named: "Algebra", in: math)
        context.createFolder(named: "Geometry", in: math)
        context.createNote(in: algebra)
        let kept = context.createNote(in: math)
        let trashed = context.createNote(in: math)

        context.trashFolder(algebra)
        context.trashNote(trashed)

        #expect(math.sortedChildren.map(\.name) == ["Geometry"])
        let counts = math.descendantCounts
        #expect(counts.folders == 1)
        #expect(counts.notes == 1)
        #expect(kept.deletedAt == nil)
    }

    @Test func restoringFolderLeavesEarlierDeletionsInRecentlyDeleted() {
        let math = context.createFolder(named: "Math")
        let deletedFirst = context.createNote(in: math)
        let deletedWithFolder = context.createNote(in: math)

        context.trashNote(deletedFirst, at: t1)
        context.trashFolder(math, at: t2)
        #expect(deletedFirst.deletedAt == t1)
        #expect(deletedWithFolder.deletedAt == t2)
        #expect(!deletedFirst.appearsInRecentlyDeleted)

        context.restoreFolder(math)

        #expect(math.deletedAt == nil)
        #expect(deletedWithFolder.deletedAt == nil)
        #expect(deletedFirst.deletedAt == t1)
        #expect(deletedFirst.appearsInRecentlyDeleted)
    }

    @Test func restoresNote() {
        let folder = context.createFolder(named: "Probability")
        let note = context.createNote(in: folder)

        context.trashNote(note)
        #expect(note.appearsInRecentlyDeleted)

        context.restoreNote(note)
        #expect(note.deletedAt == nil)
    }

    @Test func deletionTimesAreWholeSeconds() {
        let folder = context.createFolder(named: "Probability")
        let note = context.createNote(in: folder)

        context.trashNote(note, at: Date(timeIntervalSinceReferenceDate: 1_000.75))

        #expect(note.deletedAt == Date(timeIntervalSinceReferenceDate: 1_000))
    }

    @Test func purgingFolderDeletesItsTreeAndLinks() throws {
        let math = context.createFolder(named: "Math")
        let random = context.createFolder(named: "Random Variables", in: math)
        let cdf = context.createNote(in: random)
        let statistics = context.createFolder(named: "Statistics")
        let estimator = context.createNote(in: statistics)

        let link = NoteLink(kind: .prerequisite)
        context.insert(link)
        link.source = cdf
        link.target = estimator
        try context.save()

        context.trashFolder(math)
        context.purgeFolder(math)

        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.map(\.name) == ["Statistics"])
        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<NoteLink>()) == 0)
    }

    @Test func purgesOnlyExpiredItems() throws {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSinceReferenceDate: 1_000 * day)
        let folder = context.createFolder(named: "Probability")
        let expiredNote = context.createNote(in: folder)
        let recentNote = context.createNote(in: folder)
        let expiredFolder = context.createFolder(named: "Old")
        context.createNote(in: expiredFolder)

        context.trashNote(expiredNote, at: now - 31 * day)
        context.trashNote(recentNote, at: now - 1 * day)
        context.trashFolder(expiredFolder, at: now - 40 * day)

        context.purgeExpiredItems(now: now)

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.id) == [recentNote.id])
        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.map(\.name) == ["Probability"])
    }

    @Test func emptyingRecentlyDeletedKeepsLiveItems() throws {
        let folder = context.createFolder(named: "Probability")
        context.createNote(in: folder)
        let trashedNote = context.createNote(in: folder)
        let trashedFolder = context.createFolder(named: "Old", in: folder)
        context.trashNote(trashedNote)
        context.trashFolder(trashedFolder)

        context.emptyRecentlyDeleted()

        #expect(try context.fetchCount(FetchDescriptor<Note>()) == 1)
        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.map(\.name) == ["Probability"])
    }

    // MARK: Model helpers

    @Test func ancestry() {
        let math = context.createFolder(named: "Math")
        let probability = context.createFolder(named: "Probability", in: math)
        let history = context.createFolder(named: "History")

        #expect(math.isAncestor(of: probability))
        #expect(math.isAncestor(of: math))
        #expect(!probability.isAncestor(of: math))
        #expect(!history.isAncestor(of: probability))
    }

    @Test func displayTitleFallsBackToUntitled() {
        #expect(Note(title: "  \n").displayTitle == "Untitled")
        #expect(Note(title: " CDF ").displayTitle == "CDF")
    }

    @Test func summaryPrefersStatementThenFirstBodyLine() {
        let note = Note(body: "\n\n   Right-continuous.\nsecond line")
        #expect(note.summary == "Right-continuous.")

        note.statement = "  F_X(x) = P(X \\le x) "
        #expect(note.summary == "F_X(x) = P(X \\le x)")

        #expect(Note().summary == "")
    }

    @Test func unknownLinkKindReadsAsRelated() {
        let link = NoteLink(kind: .computes)
        #expect(link.kind == LinkKind.computes)

        link.kindRaw = "someFutureKind"
        #expect(link.kind == LinkKind.related)
        #expect(link.kindRaw == "someFutureKind")
    }
}
