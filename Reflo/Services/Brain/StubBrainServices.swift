import Foundation

struct StubBrainServices: BrainServices {
    func makeQuiz(bookTitle: String, chapterText: String) async throws -> [QuizQuestion] {
        _ = bookTitle
        _ = chapterText
        return [
            QuizQuestion(
                id: "q1",
                prompt: "What is the main idea this chapter is trying to convey?",
                choices: [
                    "A tempting but incomplete reading of the idea",
                    "The core connection the author makes",
                    "A detail that sounds right but misses the point",
                    "An opposite that flips cause and effect"
                ],
                correctIndex: 1,
                bookExample: "The book's own example from this chapter (placeholder).",
                idea: "The chapter's main idea is the core connection the author makes between concepts.",
                trapTypes: [
                    .overturnedCommonSenseBelief,
                    nil,
                    .falseBelief,
                    .flawedMentalModel
                ]
            ),
            QuizQuestion(
                id: "q2",
                prompt: "How does the author support that idea?",
                choices: [
                    "By listing unrelated facts",
                    "Through a concrete example and reasoning",
                    "By repeating the title",
                    "By dismissing other views without argument"
                ],
                correctIndex: 1,
                bookExample: "Another example the book uses (placeholder).",
                idea: "The author supports the idea through a concrete example and reasoning.",
                trapTypes: [
                    .falseBelief,
                    nil,
                    .unclassified,
                    .flawedMentalModel
                ]
            ),
            QuizQuestion(
                id: "q3",
                prompt: "What would misunderstanding this chapter look like in practice?",
                choices: [
                    "Applying the idea too narrowly",
                    "Using the idea where it actually fits",
                    "Connecting it to a related field",
                    "Explaining it to someone else"
                ],
                correctIndex: 0,
                bookExample: "A practical case from the text (placeholder).",
                idea: "Misunderstanding the chapter means applying the idea too narrowly.",
                trapTypes: [
                    nil,
                    .ontologicalMiscategorization,
                    .flawedMentalModel,
                    .falseBelief
                ]
            )
        ]
    }

    func mend(question: QuizQuestion, pickedChoiceIndex: Int, bookTitle: String, chapterTitle: String) async throws -> String {
        _ = question
        _ = pickedChoiceIndex
        _ = bookTitle
        _ = chapterTitle
        return "The idea isn't about memorizing a fact — it's about seeing how the pieces connect. The book's example shows one concrete case; the chapter builds toward that connection step by step."
    }

    func secondExample(for question: QuizQuestion, pickedChoiceIndex: Int) async throws -> String {
        _ = question
        _ = pickedChoiceIndex
        return "Imagine explaining this at work: you'd use a different situation, but the same underlying pattern — that's what the book's example and this one share."
    }

    func reply(narration: String, chapterText: String) async throws -> NarrationReply {
        _ = chapterText
        let trimmed = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return NarrationReply(text: "It sounds like the main thread didn't come through yet. What is the one idea you'd want to remember from this chapter?")
        }
        return NarrationReply(
            text: """
            You picked up on something real in how you described it — that thread is worth keeping.

            One piece that might still be fuzzy: how the book's example connects to the broader claim. Does the example illustrate the same mechanism the author argues for, or something adjacent?

            If it helps, compare the book's example to a situation from your own week — what would need to be true for the same pattern to show up?
            """
        )
    }
}
