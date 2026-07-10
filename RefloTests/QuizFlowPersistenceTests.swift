import Foundation
import XCTest
@testable import Reflo

@MainActor
final class QuizFlowPersistenceTests: XCTestCase {
    func testNewQuizCreatesDraftBeforeQuestionPhase() async throws {
        let store = BlockingFakeQuizAuditStore()
        let lifecycle = QuizDraftLifecycle(store: store)
        let flow = QuizAttemptFlowViewModel(
            launch: .new(id: UUID(), session: makeSession()),
            brain: StubBrainServices(),
            lifecycle: lifecycle,
            transcriber: SpeechTranscriber()
        )

        await flow.bootstrap()

        XCTAssertEqual(flow.phase, .question)
        XCTAssertNotNil(flow.draft)
        let events = await store.events
        XCTAssertEqual(events, [.createDraft])
    }

    func testResumeFromFinalizationPendingDoesNotCallBrain() async throws {
        let store = BlockingFakeQuizAuditStore()
        let lifecycle = QuizDraftLifecycle(store: store)
        let draftID = UUID()
        var draft = try await lifecycle.createDraft(id: draftID, session: makeSession(), questions: makeQuestions())
        draft = try await answerAll(using: lifecycle, draft: draft)
        draft = try await lifecycle.updateNarrationTranscript(draft: draft, text: "Summary").draft
        draft = try await lifecycle.submitNarration(draft: draft, transcript: "Summary").draft
        draft = try await store.apply(
            transition: .recordReplySuccess(text: "Reply", completedAt: Date()),
            to: draftID,
            expectedRevision: draft.revision
        )

        let flow = QuizAttemptFlowViewModel(
            launch: .resume(draftID: draftID),
            brain: FailingBrainServices(),
            lifecycle: lifecycle,
            transcriber: SpeechTranscriber()
        )

        await flow.bootstrap()
        XCTAssertEqual(flow.phase, .feedback)
        XCTAssertNotNil(flow.completedAttempt)
    }

    private func answerAll(using lifecycle: QuizDraftLifecycle, draft: QuizDraft) async throws -> QuizDraft {
        var current = draft
        for index in current.questions.indices {
            current = try await lifecycle.selectChoice(
                draft: current,
                questionIndex: index,
                selectedIndex: 1
            ).draft
        }
        return current
    }

    private func makeSession() -> ChapterSession {
        ChapterSession(
            bookID: "book-1",
            bookTitle: "Systems",
            chapterID: "ch-1",
            chapterTitle: "Chapter 1",
            chapterText: "Body"
        )
    }

    private func makeQuestions() -> [QuizQuestion] {
        [
            QuizQuestion(
                id: "q1",
                prompt: "Prompt",
                choices: ["Wrong", "Right"],
                correctIndex: 1,
                bookExample: "Example",
                idea: "Idea",
                trapTypes: [.falseBelief, nil]
            )
        ]
    }
}

private struct FailingBrainServices: BrainServices {
    func makeQuiz(bookTitle: String, chapterText: String) async throws -> [QuizQuestion] {
        throw QuizAuditStoreError.readFailed
    }

    func mend(question: QuizQuestion, pickedChoiceIndex: Int, bookTitle: String, chapterTitle: String) async throws -> String {
        throw QuizAuditStoreError.readFailed
    }

    func secondExample(for question: QuizQuestion, pickedChoiceIndex: Int) async throws -> String {
        throw QuizAuditStoreError.readFailed
    }

    func reply(narration: String, chapterText: String) async throws -> NarrationReply {
        throw QuizAuditStoreError.readFailed
    }
}
