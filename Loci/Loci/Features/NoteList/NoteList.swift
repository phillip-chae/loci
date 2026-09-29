import SwiftData
import SwiftUI

/// The notes directly inside one folder, most recently edited first.
struct NoteList: View {
    let folder: Folder
    @Binding var selection: Note?

    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]

    init(folder: Folder, selection: Binding<Note?>) {
        self.folder = folder
        _selection = selection
        let folderID = folder.id
        _notes = Query(
            filter: #Predicate<Note> { $0.folder?.id == folderID && $0.deletedAt == nil },
            sort: \Note.updatedAt,
            order: .reverse
        )
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    NoteRow(note: note)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        trash(note)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                let deleted = offsets.map { notes[$0] }
                deleted.forEach(trash)
            }
        }
        .navigationTitle(folder.name)
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Notes you add to “\(folder.name)” appear here.")
                } actions: {
                    Button("New Note", action: addNote)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private func addNote() {
        selection = modelContext.createNote(in: folder)
    }

    /// Moves a note to Recently Deleted.
    private func trash(_ note: Note) {
        if selection == note {
            selection = nil
        }
        modelContext.trashNote(note)
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.displayTitle)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(note.updatedAt, format: .relative(presentation: .named))
                Text(note.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
