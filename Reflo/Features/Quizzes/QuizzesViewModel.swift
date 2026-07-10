import Foundation

protocol QuizzesAuditStoreProtocol: Sendable {
    func listDrafts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<QuizDraftSummary>
    func listAttempts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<CompletedAttemptSummary>
    func discardDraft(id: UUID, expectedRevision: Int) async throws
    func loadAttempt(id: UUID) async throws -> CompletedQuizAttempt?
    func loadDraft(id: UUID) async throws -> QuizDraft?
}

extension FileQuizAuditStore: QuizzesAuditStoreProtocol {
    func listDrafts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<QuizDraftSummary> {
        if let chapterID, let bookID {
            return await listDrafts(forChapter: chapterID, bookID: bookID)
        }
        if let bookID {
            return await listDrafts(forBook: bookID)
        }
        return await listDrafts()
    }

    func listAttempts(forChapter chapterID: String?, bookID: String?) async -> QuizAuditListResult<CompletedAttemptSummary> {
        if let chapterID, let bookID {
            return await listAttempts(forChapter: chapterID, bookID: bookID)
        }
        if let bookID {
            return await listAttempts(forBook: bookID)
        }
        return await listAttempts()
    }

    func loadAttempt(id: UUID) async throws -> CompletedQuizAttempt? {
        try await attempt(id: id)
    }

    func loadDraft(id: UUID) async throws -> QuizDraft? {
        try await draft(id: id)
    }
}

enum QuizListItem: Identifiable, Hashable, Sendable {
    case draft(QuizDraftSummary)
    case attempt(CompletedAttemptSummary)

    var id: UUID {
        switch self {
        case .draft(let summary):
            return summary.id
        case .attempt(let summary):
            return summary.id
        }
    }

    var sortDate: Date {
        switch self {
        case .draft(let summary):
            return summary.updatedAt
        case .attempt(let summary):
            return summary.completedAt
        }
    }

    var chapterTitle: String {
        switch self {
        case .draft(let summary):
            return summary.chapterTitle
        case .attempt(let summary):
            return summary.chapterTitle
        }
    }

    var bookTitle: String {
        switch self {
        case .draft(let summary):
            return summary.bookTitle
        case .attempt(let summary):
            return summary.bookTitle
        }
    }
}

@MainActor
final class QuizzesViewModel: ObservableObject {
    @Published private(set) var items: [QuizListItem] = []
    @Published private(set) var issues: [RecoveryIssue] = []
    @Published private(set) var isLoading = false
    @Published var pendingDiscardID: UUID?
    @Published var errorMessage: String?

    private let store: any QuizzesAuditStoreProtocol
    private let chapterID: String?
    private let bookID: String?
    private var draftRevisions: [UUID: Int] = [:]

    init(store: any QuizzesAuditStoreProtocol, chapterID: String? = nil, bookID: String? = nil) {
        self.store = store
        self.chapterID = chapterID
        self.bookID = bookID
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let draftResult = await store.listDrafts(forChapter: chapterID, bookID: bookID)
        let attemptResult = await store.listAttempts(forChapter: chapterID, bookID: bookID)

        draftRevisions = Dictionary(uniqueKeysWithValues: draftResult.items.map { ($0.id, $0.revision) })
        issues = draftResult.issues + attemptResult.issues

        let combined = draftResult.items.map(QuizListItem.draft) + attemptResult.items.map(QuizListItem.attempt)
        items = combined.sorted {
            if $0.sortDate != $1.sortDate {
                return $0.sortDate > $1.sortDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func requestDiscard(draftID: UUID) {
        pendingDiscardID = draftID
    }

    func cancelDiscard() {
        pendingDiscardID = nil
    }

    func confirmDiscard() async {
        guard let draftID = pendingDiscardID else { return }
        pendingDiscardID = nil
        do {
            let revision = draftRevisions[draftID] ?? 1
            try await store.discardDraft(id: draftID, expectedRevision: revision)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class AttemptDetailViewModel: ObservableObject {
    @Published private(set) var attempt: CompletedQuizAttempt?
    @Published private(set) var draft: QuizDraft?
    @Published private(set) var loadState: LoadState<Bool> = .idle

    private let store: any QuizzesAuditStoreProtocol
    private let recordID: UUID
    private let isDraft: Bool

    init(store: any QuizzesAuditStoreProtocol, recordID: UUID, isDraft: Bool) {
        self.store = store
        self.recordID = recordID
        self.isDraft = isDraft
    }

    func load() async {
        loadState = .loading
        do {
            if isDraft {
                draft = try await store.loadDraft(id: recordID)
                guard draft != nil else {
                    loadState = .failed("Draft not found.")
                    return
                }
            } else {
                attempt = try await store.loadAttempt(id: recordID)
                guard attempt != nil else {
                    loadState = .failed("Attempt not found.")
                    return
                }
            }
            loadState = .loaded(true)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
