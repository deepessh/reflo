import Foundation

enum QuizDraftTransition: Sendable, Hashable {
    case recordCorrectAnswer(questionIndex: Int, selectedIndex: Int)
    case recordWrongAnswer(questionIndex: Int, selectedIndex: Int, requestID: UUID)
    case recordMending(questionIndex: Int, text: String)
    case recordMendingFailure(questionIndex: Int, fallbackText: String)
    case requestSecondExample(questionIndex: Int, requestID: UUID)
    case recordSecondExample(questionIndex: Int, text: String)
    case recordSecondExampleFailure(questionIndex: Int, fallbackText: String)
    case continueFromMending(questionIndex: Int)
    case updateNarrationTranscript(text: String)
    case submitNarrationForReply(requestID: UUID, transcript: String)
    case recordReplySuccess(text: String, completedAt: Date)
    case recordReplyFailure
    case retryReply(requestID: UUID)
}

enum QuizDraftTransitionApplier {
    static func apply(_ transition: QuizDraftTransition, to draft: QuizDraft, now: Date) throws -> QuizDraft {
        var updated = draft

        switch transition {
        case .recordCorrectAnswer(let questionIndex, let selectedIndex):
            try ensureStage(draft.stage, matches: .answering(questionIndex: questionIndex))
            try setAnswer(on: &updated, questionIndex: questionIndex, selectedIndex: selectedIndex)
            updated.stage = nextStageAfterAnswer(draft: updated, questionIndex: questionIndex)

        case .recordWrongAnswer(let questionIndex, let selectedIndex, let requestID):
            try ensureStage(draft.stage, matches: .answering(questionIndex: questionIndex))
            try setAnswer(on: &updated, questionIndex: questionIndex, selectedIndex: selectedIndex)
            updated.stage = .mendingPending(questionIndex: questionIndex, requestID: requestID)

        case .recordMending(let questionIndex, let text):
            try ensureMendingPending(draft.stage, questionIndex: questionIndex)
            updated.questions[questionIndex].mendingText = text
            updated.stage = .mendingReview(questionIndex: questionIndex)

        case .recordMendingFailure(let questionIndex, let fallbackText):
            try ensureMendingPending(draft.stage, questionIndex: questionIndex)
            updated.questions[questionIndex].mendingText = fallbackText
            updated.stage = .mendingReview(questionIndex: questionIndex)

        case .requestSecondExample(let questionIndex, let requestID):
            try ensureStage(draft.stage, matches: .mendingReview(questionIndex: questionIndex))
            updated.stage = .secondExamplePending(questionIndex: questionIndex, requestID: requestID)

        case .recordSecondExample(let questionIndex, let text):
            try ensureSecondExamplePending(draft.stage, questionIndex: questionIndex)
            updated.questions[questionIndex].secondExampleText = text
            updated.questions[questionIndex].secondExampleFetchFailed = false
            updated.stage = .mendingReview(questionIndex: questionIndex)

        case .recordSecondExampleFailure(let questionIndex, let fallbackText):
            try ensureSecondExamplePending(draft.stage, questionIndex: questionIndex)
            updated.questions[questionIndex].secondExampleText = fallbackText
            updated.questions[questionIndex].secondExampleFetchFailed = true
            updated.stage = .mendingReview(questionIndex: questionIndex)

        case .continueFromMending(let questionIndex):
            try ensureStage(draft.stage, matches: .mendingReview(questionIndex: questionIndex))
            updated.stage = nextStageAfterAnswer(draft: updated, questionIndex: questionIndex)

        case .updateNarrationTranscript(let text):
            try ensureStage(draft.stage, matches: .narrating)
            updated.narrationTranscript = text
            updated.stage = .narrating

        case .submitNarrationForReply(let requestID, let transcript):
            try ensureStage(draft.stage, matches: .narrating)
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw QuizAuditValidationError.emptyTranscript }
            updated.narrationTranscript = trimmed
            updated.replyFailed = false
            updated.stage = .replyPending(requestID: requestID)

        case .recordReplySuccess(let text, let completedAt):
            switch draft.stage {
            case .replyPending, .replyFailed:
                break
            default:
                throw QuizAuditValidationError.illegalTransition(from: draft.stage, to: .finalizationPending)
            }
            updated.narrationReply = text
            updated.replyFailed = false
            updated.completedAt = completedAt
            updated.stage = .finalizationPending

        case .recordReplyFailure:
            switch draft.stage {
            case .replyPending:
                updated.replyFailed = true
                updated.stage = .replyFailed
            default:
                throw QuizAuditValidationError.illegalTransition(from: draft.stage, to: .replyFailed)
            }

        case .retryReply(let requestID):
            guard draft.stage == .replyFailed else {
                throw QuizAuditValidationError.illegalTransition(from: draft.stage, to: .replyPending(requestID: requestID))
            }
            updated.replyFailed = false
            updated.stage = .replyPending(requestID: requestID)
        }

        updated.revision = draft.revision + 1
        updated.updatedAt = now
        return updated
    }

    private static func setAnswer(
        on draft: inout QuizDraft,
        questionIndex: Int,
        selectedIndex: Int
    ) throws {
        guard draft.questions.indices.contains(questionIndex) else {
            throw QuizAuditValidationError.unansweredQuestion(index: questionIndex)
        }
        let optionCount = draft.questions[questionIndex].question.options.count
        guard selectedIndex >= 0, selectedIndex < optionCount else {
            throw QuizAuditValidationError.invalidSelectedIndex(questionID: draft.questions[questionIndex].question.id)
        }
        draft.questions[questionIndex].answer = CapturedAnswer(selectedIndex: selectedIndex)
    }

    private static func nextStageAfterAnswer(draft: QuizDraft, questionIndex: Int) -> QuizDraftStage {
        if questionIndex + 1 < draft.questions.count {
            return .answering(questionIndex: questionIndex + 1)
        }
        return .narrating
    }

    private static func ensureStage(_ actual: QuizDraftStage, matches expected: QuizDraftStage) throws {
        guard actual == expected else {
            throw QuizAuditValidationError.illegalTransition(from: actual, to: expected)
        }
    }

    private static func ensureMendingPending(_ stage: QuizDraftStage, questionIndex: Int) throws {
        guard case .mendingPending(let index, _) = stage, index == questionIndex else {
            throw QuizAuditValidationError.illegalTransition(from: stage, to: .mendingReview(questionIndex: questionIndex))
        }
    }

    private static func ensureSecondExamplePending(_ stage: QuizDraftStage, questionIndex: Int) throws {
        guard case .secondExamplePending(let index, _) = stage, index == questionIndex else {
            throw QuizAuditValidationError.illegalTransition(from: stage, to: .mendingReview(questionIndex: questionIndex))
        }
    }
}
