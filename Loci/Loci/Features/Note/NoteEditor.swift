import SwiftData
import SwiftUI

/// Edits a note's fields as plain text. Changes save automatically.
struct NoteEditor: View {
    @Bindable var note: Note

    @FocusState private var focusedField: Field?

    private enum Field {
        case title, statement, body, citation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $note.title)
                .font(.title2.bold())
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .statement }
            TextField("Key statement (LaTeX)", text: $note.statement, axis: .vertical)
                .font(.body.monospaced())
                .lineLimit(1...4)
                .focused($focusedField, equals: .statement)
            Divider()
            TextEditor(text: $note.body)
                .font(.body)
                .focused($focusedField, equals: .body)
            TextField("Citation, e.g. Rice §3.5", text: $note.citation)
                .font(.footnote)
                .focused($focusedField, equals: .citation)
        }
        .textFieldStyle(.plain)
        .padding()
        .onChange(of: note.title) { note.updatedAt = .now }
        .onChange(of: note.statement) { note.updatedAt = .now }
        .onChange(of: note.body) { note.updatedAt = .now }
        .onChange(of: note.citation) { note.updatedAt = .now }
        .onAppear {
            if note.title.isEmpty && note.body.isEmpty {
                focusedField = .title
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        NoteEditor(note: PreviewData.sampleNote)
    }
    .modelContainer(PreviewData.container)
}
