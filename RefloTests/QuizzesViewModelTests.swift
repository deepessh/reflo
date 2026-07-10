import Foundation
import XCTest
@testable import Reflo

@MainActor
final class QuizzesViewModelTests: XCTestCase {
    func testDeterministicOrderingShowsDraftsAndAttempts() async {
        let store = FakeQuizzesAuditStore()
        let viewModel = QuizzesViewModel(store: store)
        await viewModel.load()

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.items.first?.id, store.newerDraftID)
    }

    func testDiscardRequiresConfirmationAndTargetsExactID() async {
        let store = FakeQuizzesAuditStore()
        let viewModel = QuizzesViewModel(store: store)
        await viewModel.load()

        await viewModel.requestDiscard(draftID: store.draftID)
        XCTAssertEqual(viewModel.pendingDiscardID, store.draftID)

        await viewModel.confirmDiscard()
        XCTAssertNil(viewModel.pendingDiscardID)
        XCTAssertTrue(store.didDiscard)
    }

    func testChapterFilterShowsOnlyMatchingRecords() async {
        let store = FakeQuizzesAuditStore()
        let viewModel = QuizzesViewModel(store: store, chapterID: "ch-1", bookID: "book-1")
        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)
    }
}

@MainActor
private final class FakeQuizzesAuditStore: QuizzesAuditStoreProtocol {
    let draftID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let newerDraftID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    var didDiscard = false

    func listDrafts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<QuizDraftSummary> {
        let drafts = [
            QuizDraftSummary(draft: makeDraft(id: draftID, updatedAt: 1)),
            QuizDraftSummary(draft: makeDraft(id: newerDraftID, updatedAt: 2))
        ]
        return QuizAuditListResult(items: drafts, issues: [])
    }

    func listAttempts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<CompletedAttemptSummary> {
        QuizAuditListResult(items: [], issues: [])
    }

    func discardDraft(id: UUID, expectedRevision: Int) async throws {
        didDiscard = true
    }

    func loadAttempt(id: UUID) async throws -> CompletedQuizAttempt? { nil }
    func loadDraft(id: UUID) async throws -> QuizDraft? { nil }

    private func makeDraft(id: UUID, updatedAt: TimeInterval) -> QuizDraft {
        QuizDraft(
            id: id,
            revision: 1,
            createdAt: Date(timeIntervalSince1970: updatedAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            chapter: CapturedChapterSnapshot(
                bookID: "book-1",
                bookTitle: "Systems",
                chapterID: "ch-1",
                chapterTitle: "Chapter 1",
                chapterText: "Body"
            ),
            questions: [],
            stage: .answering(questionIndex: 0)
        )
    }
}
