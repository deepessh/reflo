import Foundation

enum QuizAuditValidationError: Error, Equatable, LocalizedError {
    case unsupportedSchema(version: Int)
    case recordTypeMismatch(expected: String, actual: String)
    case identityMismatch(fileName: UUID, payloadID: UUID)
    case invalidTrapType(String)
    case invalidOptionCount(questionID: String)
    case missingCorrectOption(questionID: String)
    case multipleCorrectOptions(questionID: String)
    case trapOnCorrectOption(questionID: String)
    case missingTrapOnDistractor(questionID: String, optionIndex: Int)
    case invalidSelectedIndex(questionID: String)
    case unansweredQuestion(index: Int)
    case emptyTranscript
    case missingNarrationReply
    case invalidStage(QuizDraftStage)
    case illegalTransition(from: QuizDraftStage, to: QuizDraftStage)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "Unsupported schema version \(version)."
        case .recordTypeMismatch(let expected, let actual):
            return "Expected record type '\(expected)' but found '\(actual)'."
        case .identityMismatch(let fileName, let payloadID):
            return "File name \(fileName) does not match payload id \(payloadID)."
        case .invalidTrapType(let value):
            return "Invalid trap type '\(value)'."
        case .invalidOptionCount(let questionID):
            return "Question \(questionID) needs at least two options."
        case .missingCorrectOption(let questionID):
            return "Question \(questionID) must have exactly one correct option."
        case .multipleCorrectOptions(let questionID):
            return "Question \(questionID) has multiple correct options."
        case .trapOnCorrectOption(let questionID):
            return "Question \(questionID) has a trap on the correct option."
        case .missingTrapOnDistractor(let questionID, let optionIndex):
            return "Question \(questionID) distractor at index \(optionIndex) is missing a trap type."
        case .invalidSelectedIndex(let questionID):
            return "Question \(questionID) has an invalid selected index."
        case .unansweredQuestion(let index):
            return "Question at index \(index) is unanswered."
        case .emptyTranscript:
            return "Narration transcript must not be empty."
        case .missingNarrationReply:
            return "Narration reply is required for completion."
        case .invalidStage(let stage):
            return "Invalid draft stage: \(String(describing: stage))."
        case .illegalTransition(let from, let to):
            return "Illegal transition from \(String(describing: from)) to \(String(describing: to))."
        }
    }
}

enum QuizAuditValidator {
    static func validateQuestionOptions(_ question: CapturedQuizQuestion) throws {
        guard question.options.count >= 2 else {
            throw QuizAuditValidationError.invalidOptionCount(questionID: question.id)
        }

        let correctIndices = question.options.enumerated().filter(\.element.isCorrect).map(\.offset)
        guard correctIndices.count == 1 else {
            throw correctIndices.isEmpty
                ? QuizAuditValidationError.missingCorrectOption(questionID: question.id)
                : QuizAuditValidationError.multipleCorrectOptions(questionID: question.id)
        }

        for (index, option) in question.options.enumerated() {
            if option.isCorrect {
                if option.trapType != nil {
                    throw QuizAuditValidationError.trapOnCorrectOption(questionID: question.id)
                }
            } else if option.trapType == nil {
                throw QuizAuditValidationError.missingTrapOnDistractor(questionID: question.id, optionIndex: index)
            }
        }
    }

    static func validateDraftIdentity(_ draft: QuizDraft, fileID: UUID) throws {
        try validateSchema(draft.schemaVersion, recordType: draft.recordType, expectedType: QuizDraft.recordType)
        guard draft.id == fileID else {
            throw QuizAuditValidationError.identityMismatch(fileName: fileID, payloadID: draft.id)
        }
        for question in draft.questions {
            try validateQuestionOptions(question.question)
        }
    }

    static func validateAttemptIdentity(_ attempt: CompletedQuizAttempt, fileID: UUID) throws {
        try validateSchema(attempt.schemaVersion, recordType: attempt.recordType, expectedType: CompletedQuizAttempt.recordType)
        guard attempt.id == fileID else {
            throw QuizAuditValidationError.identityMismatch(fileName: fileID, payloadID: attempt.id)
        }
        for question in attempt.questions {
            try validateQuestionOptions(question.question)
        }
    }

    static func validateForCompletion(_ draft: QuizDraft) throws {
        guard case .finalizationPending = draft.stage else {
            throw QuizAuditValidationError.invalidStage(draft.stage)
        }

        for (index, question) in draft.questions.enumerated() {
            guard let answer = question.answer else {
                throw QuizAuditValidationError.unansweredQuestion(index: index)
            }
            guard answer.selectedIndex >= 0, answer.selectedIndex < question.question.options.count else {
                throw QuizAuditValidationError.invalidSelectedIndex(questionID: question.question.id)
            }
        }

        let trimmedTranscript = draft.narrationTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            throw QuizAuditValidationError.emptyTranscript
        }

        guard let reply = draft.narrationReply?.trimmingCharacters(in: .whitespacesAndNewlines), !reply.isEmpty else {
            throw QuizAuditValidationError.missingNarrationReply
        }

        guard draft.completedAt != nil else {
            throw QuizAuditValidationError.invalidStage(draft.stage)
        }
    }

    private static func validateSchema(_ version: Int, recordType: String, expectedType: String) throws {
        guard version == QuizDraft.currentSchemaVersion else {
            throw QuizAuditValidationError.unsupportedSchema(version: version)
        }
        guard recordType == expectedType else {
            throw QuizAuditValidationError.recordTypeMismatch(expected: expectedType, actual: recordType)
        }
    }
}
