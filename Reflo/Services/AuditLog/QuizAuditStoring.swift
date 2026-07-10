import Foundation

enum RecoveryIssueKind: String, Codable, Sendable {
    case corruptFile
    case unsupportedSchema
    case identityMismatch
    case shadowDraft
    case conflictingPair
}

struct RecoveryIssue: Sendable, Hashable, Identifiable {
    let id: String
    let kind: RecoveryIssueKind
    let fileURL: URL
    let message: String

    init(kind: RecoveryIssueKind, fileURL: URL, message: String) {
        self.id = fileURL.path
        self.kind = kind
        self.fileURL = fileURL
        self.message = message
    }
}

enum QuizAuditStoreError: Error, Equatable, LocalizedError {
    case draftAlreadyExists(UUID)
    case draftNotFound(UUID)
    case attemptNotFound(UUID)
    case staleRevision(expected: Int, actual: Int)
    case validation(QuizAuditValidationError)
    case attemptConflict(UUID)
    case writeFailed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .draftAlreadyExists(let id):
            return "Draft \(id) already exists."
        case .draftNotFound(let id):
            return "Draft \(id) not found."
        case .attemptNotFound(let id):
            return "Attempt \(id) not found."
        case .staleRevision(let expected, let actual):
            return "Stale revision: expected \(expected), found \(actual)."
        case .validation(let error):
            return error.localizedDescription
        case .attemptConflict(let id):
            return "Completed attempt \(id) conflicts with derived content."
        case .writeFailed:
            return "Couldn't save quiz record."
        case .readFailed:
            return "Couldn't read quiz record."
        }
    }
}

struct QuizAuditListResult<T: Sendable>: Sendable {
    let items: [T]
    let issues: [RecoveryIssue]
}

protocol QuizAuditClock: Sendable {
    func now() -> Date
}

struct SystemQuizAuditClock: QuizAuditClock {
    func now() -> Date { Date() }
}

protocol QuizAuditStoring: Actor {
    func createDraft(_ draft: QuizDraft) async throws -> QuizDraft
    func draft(id: UUID) async throws -> QuizDraft?
    func listDrafts() async -> QuizAuditListResult<QuizDraftSummary>
    func listDrafts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<QuizDraftSummary>
    func apply(transition: QuizDraftTransition, to draftID: UUID, expectedRevision: Int) async throws -> QuizDraft
    func discardDraft(id: UUID, expectedRevision: Int) async throws
    func finalize(draftID: UUID) async throws -> CompletedQuizAttempt
    func attempt(id: UUID) async throws -> CompletedQuizAttempt?
    func listAttempts() async -> QuizAuditListResult<CompletedAttemptSummary>
    func listAttempts(forChapter chapterID: String, bookID: String) async -> QuizAuditListResult<CompletedAttemptSummary>
}
