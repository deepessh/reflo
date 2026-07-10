import Foundation

enum QuizLifecycleEvent: Sendable, Equatable {
    case saveDraft
    case callMending
    case callSecondExample
    case callReply
    case finalizeAttempt
    case publishUI
    case navigate
}

struct QuizLifecycleJournal: Sendable {
    private(set) var events: [QuizLifecycleEvent] = []

    mutating func record(_ event: QuizLifecycleEvent) {
        events.append(event)
    }
}

enum QuizDraftLifecycleEffect: Sendable, Equatable {
    case none
    case fetchMending(questionIndex: Int, requestID: UUID)
    case fetchSecondExample(questionIndex: Int, requestID: UUID)
    case fetchReply(requestID: UUID)
    case finalize
    case publish
}

struct QuizDraftLifecycleResult: Sendable {
    let draft: QuizDraft
    let effect: QuizDraftLifecycleEffect
}

actor QuizDraftLifecycle {
    private let store: any QuizAuditStoring
    private let clock: any QuizAuditClock

    init(store: any QuizAuditStoring, clock: any QuizAuditClock = SystemQuizAuditClock()) {
        self.store = store
        self.clock = clock
    }

    func createDraft(
        id: UUID,
        session: ChapterSession,
        questions: [QuizQuestion]
    ) async throws -> QuizDraft {
        let draft = QuizDraft.newDraft(
            id: id,
            chapter: CapturedChapterSnapshot(session: session),
            questions: questions,
            now: clock.now()
        )
        return try await store.createDraft(draft)
    }

    func loadDraft(id: UUID) async throws -> QuizDraft? {
        try await store.draft(id: id)
    }

    func selectChoice(
        draft: QuizDraft,
        questionIndex: Int,
        selectedIndex: Int
    ) async throws -> QuizDraftLifecycleResult {
        let question = draft.questions[questionIndex]
        let isCorrect = question.question.options[selectedIndex].isCorrect

        if isCorrect {
            let updated = try await store.apply(
                transition: .recordCorrectAnswer(questionIndex: questionIndex, selectedIndex: selectedIndex),
                to: draft.id,
                expectedRevision: draft.revision
            )
            return QuizDraftLifecycleResult(draft: updated, effect: .publish)
        }

        let requestID = UUID()
        let updated = try await store.apply(
            transition: .recordWrongAnswer(
                questionIndex: questionIndex,
                selectedIndex: selectedIndex,
                requestID: requestID
            ),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(
            draft: updated,
            effect: .fetchMending(questionIndex: questionIndex, requestID: requestID)
        )
    }

    func recordMending(
        draft: QuizDraft,
        questionIndex: Int,
        text: String,
        failed: Bool
    ) async throws -> QuizDraftLifecycleResult {
        let transition: QuizDraftTransition = failed
            ? .recordMendingFailure(questionIndex: questionIndex, fallbackText: text)
            : .recordMending(questionIndex: questionIndex, text: text)
        let updated = try await store.apply(
            transition: transition,
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .publish)
    }

    func requestSecondExample(draft: QuizDraft, questionIndex: Int) async throws -> QuizDraftLifecycleResult {
        let requestID = UUID()
        let updated = try await store.apply(
            transition: .requestSecondExample(questionIndex: questionIndex, requestID: requestID),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(
            draft: updated,
            effect: .fetchSecondExample(questionIndex: questionIndex, requestID: requestID)
        )
    }

    func recordSecondExample(
        draft: QuizDraft,
        questionIndex: Int,
        text: String,
        failed: Bool
    ) async throws -> QuizDraftLifecycleResult {
        let transition: QuizDraftTransition = failed
            ? .recordSecondExampleFailure(questionIndex: questionIndex, fallbackText: text)
            : .recordSecondExample(questionIndex: questionIndex, text: text)
        let updated = try await store.apply(
            transition: transition,
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .publish)
    }

    func continueFromMending(draft: QuizDraft, questionIndex: Int) async throws -> QuizDraftLifecycleResult {
        let updated = try await store.apply(
            transition: .continueFromMending(questionIndex: questionIndex),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .publish)
    }

    func updateNarrationTranscript(draft: QuizDraft, text: String) async throws -> QuizDraftLifecycleResult {
        let updated = try await store.apply(
            transition: .updateNarrationTranscript(text: text),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .publish)
    }

    func submitNarration(draft: QuizDraft, transcript: String) async throws -> QuizDraftLifecycleResult {
        let requestID = UUID()
        let updated = try await store.apply(
            transition: .submitNarrationForReply(requestID: requestID, transcript: transcript),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .fetchReply(requestID: requestID))
    }

    func recordReplySuccess(draft: QuizDraft, replyText: String) async throws -> (draft: QuizDraft, attempt: CompletedQuizAttempt) {
        let updated = try await store.apply(
            transition: .recordReplySuccess(text: replyText, completedAt: clock.now()),
            to: draft.id,
            expectedRevision: draft.revision
        )
        let attempt = try await store.finalize(draftID: updated.id)
        return (updated, attempt)
    }

    func recordReplyFailure(draft: QuizDraft) async throws -> QuizDraftLifecycleResult {
        let updated = try await store.apply(
            transition: .recordReplyFailure,
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .publish)
    }

    func retryReply(draft: QuizDraft) async throws -> QuizDraftLifecycleResult {
        let requestID = UUID()
        let updated = try await store.apply(
            transition: .retryReply(requestID: requestID),
            to: draft.id,
            expectedRevision: draft.revision
        )
        return QuizDraftLifecycleResult(draft: updated, effect: .fetchReply(requestID: requestID))
    }

    func resumeFinalization(draft: QuizDraft) async throws -> CompletedQuizAttempt {
        try await store.finalize(draftID: draft.id)
    }

    func discardDraft(id: UUID, expectedRevision: Int) async throws {
        try await store.discardDraft(id: id, expectedRevision: expectedRevision)
    }

    func permittedEffect(for draft: QuizDraft) -> QuizDraftLifecycleEffect {
        QuizDraftLifecycle.permittedEffect(for: draft)
    }

    static func permittedEffect(for draft: QuizDraft) -> QuizDraftLifecycleEffect {
        switch draft.stage {
        case .mendingPending(_, let requestID):
            return .fetchMending(questionIndex: draft.stage.questionIndex ?? 0, requestID: requestID)
        case .secondExamplePending(_, let requestID):
            return .fetchSecondExample(questionIndex: draft.stage.questionIndex ?? 0, requestID: requestID)
        case .replyPending(let requestID):
            return .fetchReply(requestID: requestID)
        case .finalizationPending:
            return .finalize
        default:
            return .none
        }
    }
}
