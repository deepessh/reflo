import Foundation
import XCTest
@testable import Reflo

final class FileQuizAuditStoreTests: XCTestCase {
    private var rootURL: URL!
    private var store: FileQuizAuditStore!

    override func setUp() async throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = FileQuizAuditStore(rootURL: rootURL, clock: FixedQuizAuditClock())
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testCreateDraftUsesCreateWithoutOverwrite() async throws {
        let draft = makeDraft()
        _ = try await store.createDraft(draft)
        do {
            _ = try await store.createDraft(draft)
            XCTFail("Expected draftAlreadyExists")
        } catch QuizAuditStoreError.draftAlreadyExists(let id) {
            XCTAssertEqual(id, draft.id)
        }
    }

    func testStaleRevisionRejected() async throws {
        let draft = makeDraft()
        _ = try await store.createDraft(draft)
        do {
            _ = try await store.apply(
                transition: .recordCorrectAnswer(questionIndex: 0, selectedIndex: 1),
                to: draft.id,
                expectedRevision: 99
            )
            XCTFail("Expected staleRevision")
        } catch QuizAuditStoreError.staleRevision(let expected, let actual) {
            XCTAssertEqual(expected, 99)
            XCTAssertEqual(actual, 1)
        }
    }

    func testFinalizeRetryWhenDraftAbsentReturnsExistingAttempt() async throws {
        var draft = makeDraft()
        draft = try await store.createDraft(draft)
        draft = try await store.apply(
            transition: .recordCorrectAnswer(questionIndex: 0, selectedIndex: 1),
            to: draft.id,
            expectedRevision: draft.revision
        )
        draft = try await store.apply(
            transition: .recordCorrectAnswer(questionIndex: 1, selectedIndex: 1),
            to: draft.id,
            expectedRevision: draft.revision
        )
        draft = try await store.apply(
            transition: .updateNarrationTranscript(text: "My narration"),
            to: draft.id,
            expectedRevision: draft.revision
        )
        draft = try await store.apply(
            transition: .submitNarrationForReply(requestID: UUID(), transcript: "My narration"),
            to: draft.id,
            expectedRevision: draft.revision
        )
        draft = try await store.apply(
            transition: .recordReplySuccess(text: "Reply text", completedAt: Date(timeIntervalSince1970: 10)),
            to: draft.id,
            expectedRevision: draft.revision
        )

        let first = try await store.finalize(draftID: draft.id)
        let second = try await store.finalize(draftID: draft.id)
        XCTAssertEqual(first, second)
        let remainingDraft = try await store.draft(id: draft.id)
        XCTAssertNil(remainingDraft)
    }

    func testFinalizeWhenBothAbsentThrowsNotFound() async {
        let missingID = UUID()
        do {
            _ = try await store.finalize(draftID: missingID)
            XCTFail("Expected draftNotFound")
        } catch {
            guard case QuizAuditStoreError.draftNotFound(let id) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(id, missingID)
        }
    }

    func testDeterministicDraftOrdering() async throws {
        let older = makeDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let newer = makeDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        _ = try await store.createDraft(older)
        _ = try await store.createDraft(newer)

        let result = await store.listDrafts()
        XCTAssertEqual(result.items.map(\.id), [newer.id, older.id])
    }

    func testDiscardDraftRequiresRevision() async throws {
        let draft = makeDraft()
        _ = try await store.createDraft(draft)
        try await store.discardDraft(id: draft.id, expectedRevision: draft.revision)
        let remainingDraft = try await store.draft(id: draft.id)
        XCTAssertNil(remainingDraft)
    }

    func testCorruptSiblingDoesNotHideHealthyDraft() async throws {
        let draft = makeDraft()
        _ = try await store.createDraft(draft)
        let corruptURL = rootURL
            .appendingPathComponent("Drafts", isDirectory: true)
            .appendingPathComponent("not-a-uuid.json")
        try Data("{}".utf8).write(to: corruptURL)

        let result = await store.listDrafts()
        XCTAssertEqual(result.items.count, 1)
        XCTAssertFalse(result.issues.isEmpty)
    }

    private func makeDraft(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> QuizDraft {
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
                choices: ["Wrong", "Right"],
                correctIndex: 1,
                bookExample: "Example",
                idea: "Idea",
                trapTypes: [.falseBelief, nil]
            ),
            QuizQuestion(
                id: "q2",
                prompt: "Question 2",
                choices: ["Wrong", "Right"],
                correctIndex: 1,
                bookExample: "Example 2",
                idea: "Idea 2",
                trapTypes: [.flawedMentalModel, nil]
            )
        ]
        return QuizDraft.newDraft(
            id: id,
            chapter: CapturedChapterSnapshot(session: session),
            questions: questions,
            now: updatedAt
        )
    }
}

private final class FixedQuizAuditClock: QuizAuditClock, @unchecked Sendable {
    private var tick: TimeInterval = 0

    func now() -> Date {
        defer { tick += 1 }
        return Date(timeIntervalSince1970: tick)
    }
}
