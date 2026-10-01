# Loci

A notes app for math where concepts are linked like a map instead of stacked like a textbook.

Textbooks and notes are linear. An idea like *independence* appears first for events, again for random variables, and again for expectations, each time pages or chapters apart. Loci keeps each concept as a note and makes the connections between notes first-class. A link can carry the formula that relates two concepts. For example, a link $F_X \to f_X$ can be labeled $f_X(x) = F_X'(x)$. From any idea, you can jump straight to everything it touches.

## Features (planned)

- Folders nested to any depth, with notes inside
- Notes written in Markdown + LaTeX, with Anki-style fields: title, key statement, body, citation
- Nested tags (`probability/random-variables/independence`), where filtering by a tag also includes its sub-tags
- Links between notes: typed links with a formula label, `[[wikilinks]]`, and backlinks
- Graph view of a note's neighborhood or the whole library, drawing only what is on screen
- iCloud sync across iPhone, iPad and Mac

## Stack

SwiftUI (multiplatform: iOS, iPadOS, macOS) · SwiftData + CloudKit · KaTeX + SwiftMath · SwiftUI `Canvas` for the graph

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and the reasoning behind each choice.

## Repository layout

```
loci/
├── README.md
├── docs/
│   └── ARCHITECTURE.md
└── Loci/                  Xcode project folder
    ├── Loci.xcodeproj
    ├── Loci/              app sources (synchronized folder)
    └── LociTests/         unit tests, Swift Testing (synchronized folder)
```

## Getting started

1. Open `Loci/Loci.xcodeproj` in Xcode.
2. Select the **Loci** scheme and a destination (My Mac, or an iPhone/iPad simulator).
3. To run on your Mac or a device, choose your team under the Loci target's **Signing & Capabilities**. A free Personal Team works. The simulator needs no team.
4. Build and run (⌘R). Run the tests with ⌘U.

iCloud sync requires a paid Apple Developer Program membership. Without one, the app stores data on the local device only. See "Sync" in the architecture doc.

## Status

Early development. Milestones are listed in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#11-milestones).
