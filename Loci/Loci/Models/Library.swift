import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.phillipchae.Loci", category: "Library")

/// Create, delete and restore operations for the library. Views call these instead of inserting
/// and deleting models directly, so relationships and soft delete are always handled the same way.
extension ModelContext {
    /// How long notes and folders stay in Recently Deleted before they are removed for good.
    static let recentlyDeletedRetentionDays = 30

    // MARK: Creating

    @discardableResult
    func createFolder(named name: String, in parent: Folder? = nil) -> Folder {
        let folder = Folder(name: name)
        insert(folder)
        // Set the relationship from the parent's side so views observing `parent.children` refresh.
        if let parent {
            parent.children = (parent.children ?? []) + [folder]
        }
        saveOrLog()
        return folder
    }

    @discardableResult
    func createNote(in folder: Folder) -> Note {
        let note = Note()
        insert(note)
        folder.notes = (folder.notes ?? []) + [note]
        saveOrLog()
        return note
    }

    // MARK: Recently Deleted

    /// Moves a folder to Recently Deleted, along with everything beneath it that isn't there already.
    func trashFolder(_ folder: Folder, at date: Date = .now) {
        markDeleted(folder, at: Self.deletionTimestamp(date))
        saveOrLog()
    }

    func trashNote(_ note: Note, at date: Date = .now) {
        guard note.deletedAt == nil else { return }
        note.deletedAt = Self.deletionTimestamp(date)
        saveOrLog()
    }

    /// Restores a folder listed in Recently Deleted, with everything that was deleted along with it.
    /// Notes and subfolders that were deleted separately before it stay in Recently Deleted.
    func restoreFolder(_ folder: Folder) {
        guard folder.appearsInRecentlyDeleted, let date = folder.deletedAt else { return }
        restore(folder, deletedAt: date)
        saveOrLog()
    }

    func restoreNote(_ note: Note) {
        guard note.appearsInRecentlyDeleted else { return }
        note.deletedAt = nil
        saveOrLog()
    }

    /// Permanently deletes a folder and everything beneath it.
    func purgeFolder(_ folder: Folder) {
        deleteTree(folder)
        saveOrLog()
    }

    /// Permanently deletes a note and its links.
    func purgeNote(_ note: Note) {
        deletePermanently(note)
        saveOrLog()
    }

    func emptyRecentlyDeleted() {
        purgeRecentlyDeleted(deletedBefore: .distantFuture)
    }

    /// Permanently deletes anything that has been in Recently Deleted longer than the retention period.
    func purgeExpiredItems(now: Date = .now) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.recentlyDeletedRetentionDays, to: now) ?? now
        purgeRecentlyDeleted(deletedBefore: cutoff)
    }

    // MARK: Helpers

    /// Deletion times are whole seconds so a folder and the items deleted with it still match
    /// after sync, since CloudKit keeps dates only to the millisecond.
    private static func deletionTimestamp(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    private func markDeleted(_ folder: Folder, at date: Date) {
        // Anything already in Recently Deleted keeps its own timestamp, and so does everything under it.
        guard folder.deletedAt == nil else { return }
        folder.deletedAt = date
        for note in folder.notes ?? [] where note.deletedAt == nil {
            note.deletedAt = date
        }
        for child in folder.children ?? [] {
            markDeleted(child, at: date)
        }
    }

    private func restore(_ folder: Folder, deletedAt date: Date) {
        guard folder.deletedAt == date else { return }
        folder.deletedAt = nil
        for note in folder.notes ?? [] where note.deletedAt == date {
            note.deletedAt = nil
        }
        for child in folder.children ?? [] {
            restore(child, deletedAt: date)
        }
    }

    /// Everything inside a deleted folder is also deleted, so purging only the items listed in
    /// Recently Deleted covers the rest.
    private func purgeRecentlyDeleted(deletedBefore cutoff: Date) {
        let folders: [Folder]
        let notes: [Note]
        do {
            folders = try fetch(FetchDescriptor<Folder>(predicate: #Predicate<Folder> { $0.deletedAt != nil }))
            notes = try fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.deletedAt != nil }))
        } catch {
            logger.error("Couldn't fetch Recently Deleted: \(error.localizedDescription, privacy: .public)")
            return
        }
        let expiredFolders = folders.filter { $0.appearsInRecentlyDeleted && ($0.deletedAt ?? .distantFuture) < cutoff }
        let expiredNotes = notes.filter { $0.appearsInRecentlyDeleted && ($0.deletedAt ?? .distantFuture) < cutoff }
        for folder in expiredFolders {
            deleteTree(folder)
        }
        for note in expiredNotes {
            deletePermanently(note)
        }
        saveOrLog()
    }

    // The cascade rules on the models handle deletes that arrive through sync. Deleting explicitly
    // here keeps local deletes from depending on when SwiftData applies those rules.
    private func deleteTree(_ folder: Folder) {
        for child in folder.children ?? [] {
            deleteTree(child)
        }
        for note in folder.notes ?? [] {
            deletePermanently(note)
        }
        delete(folder)
    }

    private func deletePermanently(_ note: Note) {
        for link in (note.outgoing ?? []) + (note.incoming ?? []) {
            delete(link)
        }
        delete(note)
    }

    private func saveOrLog() {
        do {
            try save()
        } catch {
            logger.error("Couldn't save the library: \(error.localizedDescription, privacy: .public)")
        }
    }
}
