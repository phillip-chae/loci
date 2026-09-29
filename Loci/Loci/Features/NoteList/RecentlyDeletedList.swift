import SwiftData
import SwiftUI

/// Folders and notes in Recently Deleted. Each can be restored or deleted permanently, and
/// anything left here is removed for good after the retention period.
struct RecentlyDeletedList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Folder> { $0.deletedAt != nil }) private var deletedFolders: [Folder]
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }) private var deletedNotes: [Note]

    @State private var purgeRequest: PurgeRequest?

    var body: some View {
        // Items deleted along with a folder are covered by that folder's row, not listed separately.
        let folders = deletedFolders
            .filter(\.appearsInRecentlyDeleted)
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
        let notes = deletedNotes
            .filter(\.appearsInRecentlyDeleted)
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
        let isEmpty = folders.isEmpty && notes.isEmpty

        List {
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(folders) { folder in
                        DeletedItemRow(
                            title: folder.name,
                            systemImage: "folder",
                            deletedAt: folder.deletedAt,
                            restore: { modelContext.restoreFolder(folder) },
                            purge: { purgeRequest = .folder(folder) }
                        )
                    }
                }
            }
            if !notes.isEmpty {
                Section("Notes") {
                    ForEach(notes) { note in
                        DeletedItemRow(
                            title: note.displayTitle,
                            systemImage: "note.text",
                            deletedAt: note.deletedAt,
                            restore: { modelContext.restoreNote(note) },
                            purge: { purgeRequest = .note(note) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .overlay {
            if isEmpty {
                ContentUnavailableView(
                    "No Recently Deleted Items",
                    systemImage: "trash",
                    description: Text("Deleted notes and folders stay here for \(ModelContext.recentlyDeletedRetentionDays) days.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Empty") { purgeRequest = .all }
                    .disabled(isEmpty)
            }
        }
        .confirmationDialog(
            purgeRequest?.title ?? "",
            isPresented: Binding(
                get: { purgeRequest != nil },
                set: { if !$0 { purgeRequest = nil } }
            ),
            titleVisibility: .visible,
            presenting: purgeRequest
        ) { request in
            Button("Delete Permanently", role: .destructive) { purge(request) }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    private func purge(_ request: PurgeRequest) {
        switch request {
        case .folder(let folder): modelContext.purgeFolder(folder)
        case .note(let note): modelContext.purgeNote(note)
        case .all: modelContext.emptyRecentlyDeleted()
        }
    }
}

private enum PurgeRequest {
    case folder(Folder)
    case note(Note)
    case all

    var title: String {
        switch self {
        case .folder(let folder): "Permanently delete “\(folder.name)” and everything in it?"
        case .note(let note): "Permanently delete “\(note.displayTitle)”?"
        case .all: "Permanently delete everything in Recently Deleted?"
        }
    }
}

private struct DeletedItemRow: View {
    let title: String
    let systemImage: String
    let deletedAt: Date?
    let restore: () -> Void
    let purge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
            if let deletedAt {
                Text("Deleted \(deletedAt, format: .relative(presentation: .named))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button(action: restore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive, action: purge) {
                Label("Delete Permanently…", systemImage: "trash")
            }
        }
        // Swipe buttons avoid the destructive role, which would remove the row before the
        // confirmation dialog is answered.
        .swipeActions(edge: .leading) {
            Button(action: restore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(action: purge) {
                Label("Delete Permanently", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}
