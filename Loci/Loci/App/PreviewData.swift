import SwiftData

/// An in-memory library with sample content, for SwiftUI previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer.loci(inMemory: true)
            populate(container.mainContext)
            return container
        } catch {
            fatalError("Couldn't create the preview container: \(error)")
        }
    }()

    static var sampleNote: Note {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Note.title)]
        )
        return try! container.mainContext.fetch(descriptor).first!
    }

    private static func populate(_ context: ModelContext) {
        let probability = context.createFolder(named: "Probability")
        let randomVariables = context.createFolder(named: "Random Variables", in: probability)
        context.createFolder(named: "Independence", in: probability)
        context.createFolder(named: "Linear Algebra")

        let cdf = context.createNote(in: randomVariables)
        cdf.title = "Cumulative distribution function"
        cdf.statement = "F_X(x) = P(X \\le x)"
        cdf.body = "Non-decreasing and right-continuous, with limits 0 at -∞ and 1 at +∞."
        cdf.citation = "Lecture 3"

        let pdf = context.createNote(in: randomVariables)
        pdf.title = "Probability density function"
        pdf.statement = "f_X(x) = F_X'(x)"
        pdf.body = "Defined wherever F_X is differentiable. Integrates to 1."

        let scratch = context.createNote(in: probability)
        scratch.title = "Scratch work"
        context.trashNote(scratch)
    }
}
