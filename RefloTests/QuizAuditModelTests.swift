import Foundation
import XCTest
@testable import Reflo

final class QuizAuditModelTests: XCTestCase {
    func testTrapTypeRoundTrip() throws {
        for trap in TrapType.allCases {
            let data = try JSONEncoder().encode(trap)
            let decoded = try JSONDecoder().decode(TrapType.self, from: data)
            XCTAssertEqual(decoded, trap)
        }
    }

    func testDraftCodableRoundTrip() throws {
        let draft = makeDraft()
        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(QuizDraft.self, from: data)
        XCTAssertEqual(decoded, draft)
    }

    func testLegalCorrectAnswerTransition() throws {
        let draft = makeDraft()
        let updated = try QuizDraftTransitionApplier.apply(
            .recordCorrectAnswer(questionIndex: 0, selectedIndex: 1),
            to: draft,
            now: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(updated.stage, .answering(questionIndex: 1))
        XCTAssertEqual(updated.questions[0].answer?.selectedIndex, 1)
        XCTAssertEqual(updated.revision, draft.revision + 1)
    }

    func testIllegalTransitionFromAnsweringToMendingReview() {
        let draft = makeDraft()
        XCTAssertThrowsError(
            try QuizDraftTransitionApplier.apply(
                .recordMending(questionIndex: 0, text: "text"),
                to: draft,
                now: Date()
            )
        ) { error in
            guard case QuizAuditValidationError.illegalTransition = error else {
                return XCTFail("Expected illegalTransition, got \(error)")
            }
        }
    }

    func testWrongAnswerMovesToMendingPending() throws {
        let draft = makeDraft()
        let requestID = UUID()
        let updated = try QuizDraftTransitionApplier.apply(
            .recordWrongAnswer(questionIndex: 0, selectedIndex: 0, requestID: requestID),
            to: draft,
            now: Date()
        )
        XCTAssertEqual(updated.stage, .mendingPending(questionIndex: 0, requestID: requestID))
        XCTAssertEqual(updated.questions[0].answer?.selectedIndex, 0)
    }

    func testCompletionValidationRequiresFinalizationPending() {
        var draft = makeDraft()
        draft.stage = .narrating
        XCTAssertThrowsError(try QuizAuditValidator.validateForCompletion(draft))
    }

    func testSnapshotInvariantsRejectTrapOnCorrectOption() {
        let question = CapturedQuizQuestion(
            id: "q1",
            prompt: "Prompt",
            options: [
                CapturedQuizOption(text: "A", isCorrect: true, trapType: .falseBelief),
                CapturedQuizOption(text: "B", isCorrect: false, trapType: .flawedMentalModel)
            ],
            bookExample: "Example",
            idea: "Idea"
        )

        XCTAssertThrowsError(try QuizAuditValidator.validateQuestionOptions(question))
    }

    func testSameChapterDraftsHaveDistinctIDs() {
        let first = makeDraft(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let second = makeDraft(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        XCTAssertEqual(first.chapter.chapterID, second.chapter.chapterID)
        XCTAssertNotEqual(first.id, second.id)
    }

    private func makeDraft(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!) -> QuizDraft {
        let session = ChapterSession(
            bookID: "book-1",
            bookTitle: "Systems",
            chapterID: "ch-1",
            chapterTitle: "Chapter 1",
            chapterText: "Chapter body"
        )
        let questions = [
            QuizQuestion(
                id: "q1",
                prompt: "Question 1",
                choices: ["Wrong", "Right", "Also wrong", "Nope"],
                correctIndex: 1,
                bookExample: "Example",
                idea: "Idea",
                trapTypes: [.falseBelief, nil, .flawedMentalModel, .unclassified]
            ),
            QuizQuestion(
                id: "q2",
                prompt: "Question 2",
                choices: ["Wrong", "Right"],
                correctIndex: 1,
                bookExample: "Example 2",
                idea: "Idea 2",
                trapTypes: [.ontologicalMiscategorization, nil]
            )
        ]
        return QuizDraft.newDraft(
            id: id,
            chapter: CapturedChapterSnapshot(session: session),
            questions: questions,
            now: Date(timeIntervalSince1970: 0)
        )
    }
}
