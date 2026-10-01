import SwiftData
import SwiftUI

enum SidebarItem: Hashable {
    case folder(Folder)
    case recentlyDeleted
}

/// The folder tree, then Recently Deleted. Top-level folders are the notebooks; any folder can
/// hold subfolders.
struct FolderSidebar: View {
    @Binding var selection: SidebarItem?

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Folder> { $0.parent == nil && $0.deletedAt == nil })
    private var rootFolders: [Folder]

    @State private var expanded: Set<UUID> = []
    @State private var nameRequest: FolderNameRequest?
    @State private var draftName = ""
    @State private var folderPendingDeletion: Folder?

    var body: some View {
        List(selection: $selection) {
            Section("Folders") {
                ForEach(rootFolders.sorted(by: Folder.byName)) { folder in
                    FolderTreeRow(folder: folder, expanded: $expanded, actions: rowActions)
                }
            }
            Section {
                NavigationLink(value: SidebarItem.recentlyDeleted) {
                    Label("Recently Deleted", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Loci")
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    requestName(.create(parent: nil))
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert(
            nameRequest?.title ?? "",
            isPresented: Binding(
                get: { nameRequest != nil },
                set: { if !$0 { nameRequest = nil } }
            ),
            presenting: nameRequest
        ) { request in
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button(request.confirmLabel) { commitName(for: request) }
        }
        .confirmationDialog(
            folderPendingDeletion.map { "Delete “\($0.name)”?" } ?? "",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { folder in
            Button("Delete Folder", role: .destructive) { trash(folder) }
        } message: { folder in
            Text(deletionMessage(for: folder))
        }
    }

    private var rowActions: FolderRowActions {
        FolderRowActions(
            newSubfolder: { requestName(.create(parent: $0)) },
            rename: { requestName(.rename($0)) },
            delete: requestTrash
        )
    }

    private func requestName(_ request: FolderNameRequest) {
        switch request {
        case .create: draftName = ""
        case .rename(let folder): draftName = folder.name
        }
        nameRequest = request
    }

    private func commitName(for request: FolderNameRequest) {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch request {
        case .create(let parent):
            let folder = modelContext.createFolder(named: name.isEmpty ? "New Folder" : name, in: parent)
            if let parent {
                expanded.insert(parent.id)
            }
            selection = .folder(folder)
        case .rename(let folder):
            if !name.isEmpty {
                folder.name = name
            }
        }
    }

    /// Empty folders go straight to Recently Deleted; folders with contents ask first.
    private func requestTrash(_ folder: Folder) {
        let counts = folder.descendantCounts
        if counts.folders == 0 && counts.notes == 0 {
            trash(folder)
        } else {
            folderPendingDeletion = folder
        }
    }

    private func trash(_ folder: Folder) {
        // Clear the selection first so no column is still showing a deleted folder.
        if case .folder(let selected)? = selection, folder.isAncestor(of: selected) {
            selection = nil
        }
        modelContext.trashFolder(folder)
    }

    private func deletionMessage(for folder: Folder) -> String {
        let counts = folder.descendantCounts
        var contents: [String] = []
        if counts.folders > 0 {
            contents.append(counts.folders == 1 ? "1 subfolder" : "\(counts.folders) subfolders")
        }
        if counts.notes > 0 {
            contents.append(counts.notes == 1 ? "1 note" : "\(counts.notes) notes")
        }
        return "Its \(contents.joined(separator: " and ")) will move to Recently Deleted too."
    }
}

private enum FolderNameRequest {
    case create(parent: Folder?)
    case rename(Folder)

    var title: String {
        switch self {
        case .create(parent: .none): "New Folder"
        case .create: "New Subfolder"
        case .rename: "Rename Folder"
        }
    }

    var confirmLabel: String {
        switch self {
        case .create: "Create"
        case .rename: "Rename"
        }
    }
}

struct FolderRowActions {
    var newSubfolder: (Folder) -> Void
    var rename: (Folder) -> Void
    var delete: (Folder) -> Void
}

/// One folder in the sidebar, plus its subfolders when expanded.
struct FolderTreeRow: View {
    let folder: Folder
    @Binding var expanded: Set<UUID>
    let actions: FolderRowActions

    var body: some View {
        let children = folder.sortedChildren
        if children.isEmpty {
            label
        } else {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    FolderTreeRow(folder: child, expanded: $expanded, actions: actions)
                }
            } label: {
                label
            }
        }
    }

    private var label: some View {
        NavigationLink(value: SidebarItem.folder(folder)) {
            Label(folder.name, systemImage: "folder")
        }
        .contextMenu {
            Button {
                actions.newSubfolder(folder)
            } label: {
                Label("New Subfolder", systemImage: "folder.badge.plus")
            }
            Button {
                actions.rename(folder)
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                actions.delete(folder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding {
            expanded.contains(folder.id)
        } set: { isExpanded in
            if isExpanded {
                expanded.insert(folder.id)
            } else {
                expanded.remove(folder.id)
            }
        }
    }
}
