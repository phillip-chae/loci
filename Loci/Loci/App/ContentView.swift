import SwiftData
import SwiftUI

/// Three columns: the sidebar, the notes in the selected folder (or Recently Deleted), and the
/// note editor. On iPhone the same view collapses into a navigation stack.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var sidebarSelection: SidebarItem?
    @State private var selectedNote: Note?

    var body: some View {
        NavigationSplitView {
            FolderSidebar(selection: $sidebarSelection)
        } content: {
            switch sidebarSelection {
            case .folder(let folder)?:
                NoteList(folder: folder, selection: $selectedNote)
                    .id(folder.id)
            case .recentlyDeleted?:
                RecentlyDeletedList()
            case nil:
                ContentUnavailableView(
                    "No Folder Selected",
                    systemImage: "folder",
                    description: Text("Choose a folder in the sidebar, or create one with the New Folder button.")
                )
            }
        } detail: {
            if let selectedNote {
                NoteEditor(note: selectedNote)
                    .id(selectedNote.id)
            } else {
                ContentUnavailableView("No Note Selected", systemImage: "note.text")
            }
        }
        .onChange(of: sidebarSelection) {
            selectedNote = nil
        }
        .task {
            modelContext.purgeExpiredItems()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}

#Preview("Empty library") {
    ContentView()
        .modelContainer(try! ModelContainer.loci(inMemory: true))
}
