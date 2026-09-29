# Loci Architecture

Draft, with decisions as of 2026-09-29. Update this file when a decision changes.

## 1. Goals

1. Make the connections between concepts visible and one tap away.
2. Stay fast with thousands of notes. Nothing is loaded or drawn unless it is on screen or about to be.
3. Look and behave like a standard Apple app on iPhone, iPad and Mac.
4. Sync through the user's own iCloud, with no server of our own.

### Interpretations

- **Notebook = folder.** There is one `Folder` type, and it nests to any depth. Top-level folders play the role of notebooks.
- **One library, one graph.** Folders organize notes, and links connect them. A link can cross folders, for example from a probability note to a statistics note. The graph view can be limited to a folder, a tag filter, or one note's neighborhood.

## 2. Decisions

| Area | Decision | Why |
|---|---|---|
| UI | SwiftUI, one multiplatform target (iOS, iPadOS, macOS) | Native look and feel. Standard controls follow the current system design automatically. |
| OS targets | Newest OS releases only, for now | Personal app, so we can use the latest APIs. Lower the targets later if needed. |
| Storage | SwiftData | Least code, and it plugs directly into SwiftUI (`@Query`). |
| Sync | CloudKit private database, through SwiftData | Apple handles transport, push notifications and merging. No server to run. |
| Math in the open note | KaTeX in one reused `WKWebView` | Full LaTeX coverage plus Markdown. |
| Math on graph nodes and in lists | SwiftMath (native), rendered to cached images | Avoids a web view per node. |
| Graph | One SwiftUI `Canvas`, drawing only what is visible, with less detail when zoomed out | Cost grows with what is on screen, not with library size. |
| Project | Created in Xcode, with synchronized folders | Files added to the source folder build without editing the project file. |

## 3. Data model

Four SwiftData models. `NoteLink` is not called `Link` because SwiftUI already has a `Link` view.

```swift
@Model final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Double = 0              // to-many relationships are unordered
    var createdAt: Date = Date.now
    var deletedAt: Date?                   // soft delete, for "Recently Deleted"
    var parent: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder]? = []
    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note]? = []
}

@Model final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var statement: String = ""             // key formula or definition (LaTeX), shown on graph nodes and in lists
    var body: String = ""                  // Markdown + LaTeX
    var citation: String = ""              // e.g. "Rice §3.5"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var deletedAt: Date?
    var graphX: Double?                    // saved layout position; nil = not placed yet
    var graphY: Double?
    var folder: Folder?
    @Relationship(inverse: \Tag.notes)
    var tags: [Tag]? = []
    @Relationship(deleteRule: .cascade, inverse: \NoteLink.source)
    var outgoing: [NoteLink]? = []
    @Relationship(deleteRule: .cascade, inverse: \NoteLink.target)
    var incoming: [NoteLink]? = []
}

@Model final class Tag {
    var id: UUID = UUID()
    var name: String = ""                  // one path segment, e.g. "independence"
    var colorHex: String?
    var parent: Tag?
    @Relationship(deleteRule: .cascade, inverse: \Tag.parent)
    var children: [Tag]? = []
    var notes: [Note]? = []
}

@Model final class NoteLink {
    var id: UUID = UUID()
    var kindRaw: String = "related"        // LinkKind raw value
    var label: String = ""                 // optional LaTeX relating the two notes
    var originRaw: String = "manual"       // manual | wikilink | suggestion
    var createdAt: Date = Date.now
    var source: Note?
    var target: Note?
}
```

### Link kinds

A link's label is where "how one measure computes another" lives.

| Kind | Meaning (source → target) | Example |
|---|---|---|
| `computes` | Target can be computed from source | $F_X \to f_X$, labeled $f_X(x) = F_X'(x)$. $f_X \to F_X$, labeled $F_X(x) = \int_{-\infty}^{x} f_X(t)\,dt$ |
| `generalizes` | Source extends target to a broader setting | Independent random variables → independent events |
| `prerequisite` | Source is needed to understand target | Conditional probability → Bayes' rule |
| `contrasts` | Easily confused, and the label says how they differ | Disjoint events ↔ independent events, labeled $P(A \cap B) = 0 \neq P(A)P(B)$ when $P(A), P(B) > 0$ |
| `related` | Anything else. Wikilinks create this kind | |

Kinds are stored as raw strings, so new kinds can be added without a schema change.

### CloudKit rules the model must follow

- Every stored property has a default value or is optional.
- Every relationship is optional and has an explicit inverse.
- No `@Attribute(.unique)` or `#Unique`. Uniqueness is by convention: a UUID is set on creation. A dedupe pass on launch merges duplicates caused by offline edits on two devices, such as two `probability` tags with the same parent.
- No `.deny` delete rule.
- To-many relationships are unordered, so anything shown in a manual order needs a `sortIndex`.
- **Once the schema is deployed to CloudKit Production, changes are additive only.** Record types and fields cannot be deleted or renamed. Iterate freely in the Development environment, and promote only when the model is stable.
- Use a `VersionedSchema` and a `SchemaMigrationPlan` from v1, so later migrations are routine.

## 4. Sync

- CloudKit private database, container `iCloud.<bundle id>`.
- Requirements: a paid Apple Developer Program membership, the iCloud capability (CloudKit plus the container), and on iOS, Background Modes → Remote notifications.
- Until those are in place, use `ModelConfiguration(cloudKitDatabase: .none)`. Switch to `.automatic` once they are ready. The model already follows the CloudKit rules above, so enabling sync requires no model changes.
- Expectations: this is not live collaboration. While online, changes usually reach other devices within seconds to a minute. Offline edits sync on reconnect. Conflicts resolve per record with last writer wins, so editing the same note on two devices while offline keeps only one version. That is acceptable for a single user; revisit if it becomes a problem, for example by keeping both copies.
- Builds run from Xcode use the CloudKit Development environment. Its data is separate from Production (TestFlight and the App Store).

## 5. Rendering math

- **Viewing a note:** a single shared `WKWebView` is reused for every note, rather than one per note. KaTeX, markdown-it and a math plugin are bundled in the app, so rendering works offline with no CDN. Swift sends `{title, statement, body}` as JSON, and JavaScript renders it. Math is pulled out before Markdown parsing, so `_` and `*` inside LaTeX are not treated as emphasis.
- **Delimiters:** `$…$` and `\(…\)` for inline math, `$$…$$` and `\[…\]` for display math. Both styles are supported so that Anki-style notes can be pasted in.
- **Editing:** plain-text LaTeX source with a live preview. The preview sits beside the editor on iPad and Mac and is a toggle on iPhone. The preview re-renders a short time after typing stops.
- **Graph nodes and list rows:** SwiftMath renders `statement` natively into an image. Images are cached in an `NSCache` keyed by LaTeX, font size and color scheme. Formulas are rendered only for visible nodes, and only when zoomed in.
- **Fallback:** if SwiftMath cannot parse an expression, show the raw LaTeX in a monospaced font.

## 6. Graph view

Two modes:

- **Local graph (default):** the open note and its neighbors up to one or two links away. It is small and fast, and it answers "what connects to this?"
- **Global graph:** the whole library, or a subset filtered by folder or tags.

Performance rules:

1. **Draw from a snapshot, not the models.** A `@ModelActor` builds a `GraphSnapshot` in the background: arrays of IDs, positions, titles, statements and edge index pairs. It fetches with `propertiesToFetch`, so note bodies are never loaded.
2. **Use one `Canvas`,** not one SwiftUI view per node.
3. **Draw only what is on screen.** A spatial grid index finds the nodes and edges inside the viewport. The same grid handles taps.
4. **Show less detail when zoomed out:** dots, then titles, then formula images as you zoom in.
5. **Keep the layout stable.** The force-directed layout runs on a background task and uses the Barnes–Hut approximation for large graphs. Positions are saved to `graphX`/`graphY` when the layout settles or when the user drags a node, not every frame, to avoid sync traffic. A new note is placed near the notes it links to, and existing nodes stay where they are, so the map stays familiar.

## 7. Tags

- Tags form a tree of `Tag` records and are shown and typed as paths, e.g. `probability/random-variables/independence`. Typing a new path creates any missing levels.
- Tags are assigned in a tag field with path autocomplete, not as inline `#tags` in the body. This avoids clashing with Markdown headings.
- **Filtering:** selecting a tag matches notes that have that tag or any tag beneath it. With several tags selected, the default is AND, with a toggle for OR. Implementation: expand the selection to the IDs of every tag beneath it in memory (the tag tree is small), collect the notes, then intersect or union. Excluding a tag (NOT) comes later.

## 8. Links

- **Manual:** from a note's inspector, choose Add link, search for a note, pick a kind, and optionally add a formula label.
- **Wikilinks:** `[[Title]]` or `[[Title|shown text]]` in the body. On save, the body is parsed and its `wikilink` links are added or removed to match. Links that don't match any note appear dimmed, and tapping one creates that note. Titles are matched in the same folder first, then across the library; if several notes match, the app asks. Renaming a note offers to update `[[old title]]` references.
- **Backlinks:** the inspector lists incoming links, each with a snippet of surrounding text.
- **Suggestions (later milestone):** never created automatically, and each can be accepted or dismissed. Candidate signals:
  1. Unlinked mentions: a note's body contains another note's title.
  2. Shared LaTeX symbols: normalize and index symbols such as `F_X`, `f_{X,Y}` and `P(A \cap B)`, and suggest notes that share rare ones.
  3. Tags that often appear together.
  4. Semantic similarity using on-device embeddings (NaturalLanguage), or Apple's on-device Foundation Models framework to propose a link kind and label.

## 9. UI structure

- `NavigationSplitView`: the sidebar (folder tree, tag tree, Recently Deleted) leads to the note list (sortable, searchable, filter chips), which leads to the detail pane (note view or editor). A toolbar button switches the detail pane to the graph.
- The inspector (`.inspector`) shows outgoing links, backlinks, suggestions, tags, citation, and a small local graph.
- On iPhone, the split view collapses into a navigation stack automatically.
- Only standard controls, with no custom window chrome, so the app picks up the current system design automatically.
- Keyboard shortcuts on Mac and iPad: new note, new folder, add link, toggle graph.

## 10. Source layout

```
Loci/Loci/
├── App/              LociApp.swift, model container setup
├── Models/           Folder, Note, Tag, NoteLink, LinkKind, schema versions
├── Features/
│   ├── Library/      sidebar: folder tree, tag tree
│   ├── NoteList/
│   ├── Note/         viewer, editor, inspector
│   └── Graph/        GraphSnapshot, GraphLayout, GraphCanvas
├── Rendering/        MathWebRenderer (KaTeX), FormulaImageCache (SwiftMath)
├── Services/         WikilinkParser, TagFilter, LinkSuggester, Deduplicator
└── Resources/katex/  katex, markdown-it, render.html
```

## 11. Milestones

1. **Library:** nested folders and note create/edit/delete (plain text), with soft delete.
2. **Math:** KaTeX viewer with editor preview, and SwiftMath previews of each note's statement.
3. **Tags:** nested tags and filtering.
4. **Links:** typed manual links, wikilinks, backlinks, inspector.
5. **Graph:** local graph first, then the global graph with visible-only drawing, zoom levels and a saved layout.
6. **Sync:** turn on CloudKit, test on two devices, dedupe pass.
7. **Suggestions:** suggested links from the signals in §8.

Later: import (Markdown, Anki), export, web version.

## 12. Porting to the web later

- **Data:** CloudKit JS can read and write the same private database from a web app after the user signs in with their Apple Account. SwiftData's CloudKit records use Core Data naming (`CD_Note`, `CD_title`, …), which works but is awkward.
- **Rendering:** the KaTeX + markdown-it renderer is already JavaScript, so it carries over to the web as-is.
- **Graph:** the layout algorithm ports directly. Only the drawing layer needs rewriting (HTML canvas or WebGL).

## 13. Open questions

- Suggested links: which signals are worth it? Decide at milestone 7.
- A review mode (Anki-style spaced repetition)? Out of scope for v1.
- A handwriting (PencilKit) field in notes?
- Import of existing notes (Markdown, Anki decks)?
- Should a link be able to point at a specific equation or heading inside a note, not just the note?
