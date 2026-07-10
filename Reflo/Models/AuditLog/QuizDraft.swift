import Foundation

enum QuizDraftStage: Codable, Sendable, Hashable {
    case answering(questionIndex: Int)
    case mendingPending(questionIndex: Int, requestID: UUID)
    case mendingReview(questionIndex: Int)
    case secondExamplePending(questionIndex: Int, requestID: UUID)
    case narrating
    case replyPending(requestID: UUID)
    case replyFailed
    case finalizationPending

    var questionIndex: Int? {
        switch self {
        case .answering(let index),
             .mendingPending(let index, _),
             .mendingReview(let index),
             .secondExamplePending(let index, _):
            return index
        case .narrating, .replyPending, .replyFailed, .finalizationPending:
            return nil
        }
    }
}

struct QuizDraft: Codable, Sendable, Hashable, Identifiable {
    static let currentSchemaVersion = 1
    static let recordType = "quiz_draft"

    let schemaVersion: Int
    let recordType: String
    let id: UUID
    var revision: Int
    let createdAt: Date
    var updatedAt: Date
    let chapter: CapturedChapterSnapshot
    var questions: [CapturedQuestionState]
    var stage: QuizDraftStage
    var narrationTranscript: String
    var narrationReply: String?
    var replyFailed: Bool
    var completedAt: Date?

    init(
        id: UUID,
        revision: Int,
        createdAt: Date,
        updatedAt: Date,
        chapter: CapturedChapterSnapshot,
        questions: [CapturedQuestionState],
        stage: QuizDraftStage,
        narrationTranscript: String = "",
        narrationReply: String? = nil,
        replyFailed: Bool = false,
        completedAt: Date? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        recordType = Self.recordType
        self.id = id
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chapter = chapter
        self.questions = questions
        self.stage = stage
        self.narrationTranscript = narrationTranscript
        self.narrationReply = narrationReply
        self.replyFailed = replyFailed
        self.completedAt = completedAt
    }

    static func newDraft(
        id: UUID,
        chapter: CapturedChapterSnapshot,
        questions: [QuizQuestion],
        now: Date
    ) -> QuizDraft {
        QuizDraft(
            id: id,
            revision: 1,
            createdAt: now,
            updatedAt: now,
            chapter: chapter,
            questions: questions.map { CapturedQuestionState(from: $0) },
            stage: .answering(questionIndex: 0)
        )
    }
}

struct CompletedQuizAttempt: Codable, Sendable, Hashable, Identifiable {
    static let currentSchemaVersion = 1
    static let recordType = "completed_quiz_attempt"

    let schemaVersion: Int
    let recordType: String
    let id: UUID
    let createdAt: Date
    let completedAt: Date
    let chapter: CapturedChapterSnapshot
    let questions: [CapturedQuestionState]
    let narrationTranscript: String
    let narrationReply: String

    init(from draft: QuizDraft) {
        schemaVersion = Self.currentSchemaVersion
        recordType = Self.recordType
        id = draft.id
        createdAt = draft.createdAt
        completedAt = draft.completedAt ?? draft.updatedAt
        chapter = draft.chapter
        questions = draft.questions
        narrationTranscript = draft.narrationTranscript
        narrationReply = draft.narrationReply ?? ""
    }
}

struct QuizDraftSummary: Sendable, Hashable, Identifiable {
    let id: UUID
    let revision: Int
    let bookID: String
    let bookTitle: String
    let chapterID: String
    let chapterTitle: String
    let stage: QuizDraftStage
    let createdAt: Date
    let updatedAt: Date
    let questionCount: Int

    init(draft: QuizDraft) {
        id = draft.id
        revision = draft.revision
        bookID = draft.chapter.bookID
        bookTitle = draft.chapter.bookTitle
        chapterID = draft.chapter.chapterID
        chapterTitle = draft.chapter.chapterTitle
        stage = draft.stage
        createdAt = draft.createdAt
        updatedAt = draft.updatedAt
        questionCount = draft.questions.count
    }
}

struct CompletedAttemptSummary: Sendable, Hashable, Identifiable {
    let id: UUID
    let bookID: String
    let bookTitle: String
    let chapterID: String
    let chapterTitle: String
    let createdAt: Date
    let completedAt: Date
    let questionCount: Int

    init(attempt: CompletedQuizAttempt) {
        id = attempt.id
        bookID = attempt.chapter.bookID
        bookTitle = attempt.chapter.bookTitle
        chapterID = attempt.chapter.chapterID
        chapterTitle = attempt.chapter.chapterTitle
        createdAt = attempt.createdAt
        completedAt = attempt.completedAt
        questionCount = attempt.questions.count
    }
}
