import Foundation
import XCTest
@testable import Reflo

final class QuizDraftLifecycleTests: XCTestCase {
    func testWrongAnswerSavesBeforeMendingCall() async throws {
        let store = BlockingFakeQuizAuditStore()
        let lifecycle = QuizDraftLifecycle(store: store)
        let draft = try await lifecycle.createDraft(
            id: UUID(),
            session: makeSession(),
            questions: makeQuestions()
        )

        var journal = QuizLifecycleJournal()
        journal.record(.saveDraft)

        let result = try await lifecycle.selectChoice(
            draft: draft,
            questionIndex: 0,
            selectedIndex: 0
        )

        journal.record(.callMending)
        if case .fetchMending(let questionIndex, let requestID) = result.effect {
            XCTAssertEqual(questionIndex, 0)
            XCTAssertNotNil(requestID)
        } else {
            XCTFail("Expected fetchMending effect")
        }
        let events = await store.events
        XCTAssertEqual(events, [.createDraft, .applyTransition])
        XCTAssertEqual(journal.events, [.saveDraft, .callMending])
    }

    func testSaveFailurePreventsDependentEffect() async throws {
        let store = BlockingFakeQuizAuditStore()
        await store.setShouldFailApply(true)
        let lifecycle = QuizDraftLifecycle(store: store)
        let draft = try await lifecycle.createDraft(
            id: UUID(),
            session: makeSession(),
            questions: makeQuestions()
        )

        do {
            _ = try await lifecycle.selectChoice(draft: draft, questionIndex: 0, selectedIndex: 1)
            XCTFail("Expected failure")
        } catch {
            let events = await store.events
            XCTAssertEqual(events, [.createDraft, .applyTransition])
        }
    }

    func testFinalizationPendingNeverCallsBrain() async throws {
        let store = BlockingFakeQuizAuditStore()
        let lifecycle = QuizDraftLifecycle(store: store)
        var draft = try await lifecycle.createDraft(
            id: UUID(),
            session: makeSession(),
            questions: makeQuestions()
        )

        draft = try await answerAllCorrect(using: lifecycle, draft: draft)
        draft = try await lifecycle.updateNarrationTranscript(draft: draft, text: "Narration").draft
        draft = try await lifecycle.submitNarration(draft: draft, transcript: "Narration").draft
        draft = try await lifecycle.recordReplySuccess(draft: draft, replyText: "Reply").draft

        XCTAssertEqual(QuizDraftLifecycle.permittedEffect(for: draft), .finalize)
        _ = try await lifecycle.resumeFinalization(draft: draft)
        let events = await store.events
        XCTAssertTrue(events.contains(.finalize))
    }

    private func answerAllCorrect(using lifecycle: QuizDraftLifecycle, draft: QuizDraft) async throws -> QuizDraft {
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

actor BlockingFakeQuizAuditStore: QuizAuditStoring {
    enum Event: Equatable {
        case createDraft
        case applyTransition
        case discardDraft
        case finalize
    }

    private var drafts: [UUID: QuizDraft] = [:]
    private var attempts: [UUID: CompletedQuizAttempt] = [:]
    private(set) var events: [Event] = []
    private var shouldFailApply = false

    func setShouldFailApply(_ value: Bool) {
        shouldFailApply = value
    }

    func createDraft(_ draft: QuizDraft) async throws -> QuizDraft {
        events.append(.createDraft)
        drafts[draft.id] = draft
        return draft
    }

    func draft(id: UUID) async throws -> QuizDraft? {
        drafts[id]
    }

    func listDrafts() async -> QuizAuditListResult<QuizDraftSummary> {
        QuizAuditListResult(items: drafts.values.map(QuizDraftSummary.init).sorted { $0.updatedAt > $1.updatedAt }, issues: [])
    }

    func listDrafts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<QuizDraftSummary> {
        let filtered = drafts.values.filter { $0.chapter.chapterID == chapterID && $0.chapter.bookID == bookID }
        return QuizAuditListResult(items: filtered.map(QuizDraftSummary.init), issues: [])
    }

    func apply(transition: QuizDraftTransition, to draftID: UUID, expectedRevision: Int) async throws -> QuizDraft {
        events.append(.applyTransition)
        if shouldFailApply { throw QuizAuditStoreError.writeFailed }
        guard var draft = drafts[draftID], draft.revision == expectedRevision else {
            throw QuizAuditStoreError.staleRevision(expected: expectedRevision, actual: drafts[draftID]?.revision ?? -1)
        }
        draft = try QuizDraftTransitionApplier.apply(transition, to: draft, now: Date())
        drafts[draftID] = draft
        return draft
    }

    func discardDraft(id: UUID, expectedRevision: Int) async throws {
        events.append(.discardDraft)
        guard let draft = drafts[id], draft.revision == expectedRevision else {
            throw QuizAuditStoreError.staleRevision(expected: expectedRevision, actual: drafts[id]?.revision ?? -1)
        }
        drafts.removeValue(forKey: id)
    }

    func finalize(draftID: UUID) async throws -> CompletedQuizAttempt {
        events.append(.finalize)
        if let attempt = attempts[draftID] { return attempt }
        guard let draft = drafts[draftID] else {
            throw QuizAuditStoreError.draftNotFound(draftID)
        }
        let attempt = CompletedQuizAttempt(from: draft)
        attempts[draftID] = attempt
        drafts.removeValue(forKey: draftID)
        return attempt
    }

    func attempt(id: UUID) async throws -> CompletedQuizAttempt? {
        attempts[id]
    }

    func listAttempts() async -> QuizAuditListResult<CompletedAttemptSummary> {
        QuizAuditListResult(items: attempts.values.map(CompletedAttemptSummary.init), issues: [])
    }

    func listAttempts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<CompletedAttemptSummary> {
        let filtered = attempts.values.filter { $0.chapter.chapterID == chapterID && $0.chapter.bookID == bookID }
        return QuizAuditListResult(items: filtered.map(CompletedAttemptSummary.init), issues: [])
    }
}
