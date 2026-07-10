import SwiftUI

private let logger = AppLog.library

@MainActor
final class ChaptersViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[Chapter]> = .idle
    @Published private(set) var bookTitle = ""
    @Published var rowStates: [String: LoadState<String>] = [:]
    @Published var rowErrors: [String: String] = [:]
    @Published private(set) var chapterDrafts: [String: [QuizDraftSummary]] = [:]
    @Published private(set) var chapterAttempts: [String: [CompletedAttemptSummary]] = [:]

    private let bookID: String
    private let libraryStore: LibraryStore
    private let epubBookCache: EPUBBookCache
    private let auditLogStore: any QuizzesAuditStoreProtocol

    init(
        bookID: String,
        libraryStore: LibraryStore,
        epubBookCache: EPUBBookCache,
        auditLogStore: any QuizzesAuditStoreProtocol
    ) {
        self.bookID = bookID
        self.libraryStore = libraryStore
        self.epubBookCache = epubBookCache
        self.auditLogStore = auditLogStore
    }

    func load() async {
        logger.debug("ChaptersViewModel.load book='\(self.bookID, privacy: .public)'")
        loadState = .loading
        do {
            guard let book = try await libraryStore.book(for: bookID) else {
                logger.error("ChaptersViewModel.load book missing '\(self.bookID, privacy: .public)'")
                loadState = .failed("Book file is missing.")
                return
            }
            bookTitle = try await epubBookCache.title(for: book)
            let chapters = try await epubBookCache.chapters(for: book)
            loadState = .loaded(chapters)
            await refreshQuizHistory()
        } catch {
            logger.error("ChaptersViewModel.load failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(error.localizedDescription)
        }
    }

    func refreshQuizHistory() async {
        let draftResult = await auditLogStore.listDrafts(forChapter: nil, bookID: bookID)
        let attemptResult = await auditLogStore.listAttempts(forChapter: nil, bookID: bookID)

        var draftsByChapter: [String: [QuizDraftSummary]] = [:]
        for draft in draftResult.items {
            draftsByChapter[draft.chapterID, default: []].append(draft)
        }
        chapterDrafts = draftsByChapter

        var attemptsByChapter: [String: [CompletedAttemptSummary]] = [:]
        for attempt in attemptResult.items {
            attemptsByChapter[attempt.chapterID, default: []].append(attempt)
        }
        chapterAttempts = attemptsByChapter
    }

    func latestDraft(for chapterID: String) -> QuizDraftSummary? {
        chapterDrafts[chapterID]?.sorted { $0.updatedAt > $1.updatedAt }.first
    }

    func startNewQuiz(for chapter: Chapter) async -> QuizLaunch? {
        guard let session = await makeSession(for: chapter) else { return nil }
        return .new(id: UUID(), session: session)
    }

    func resumeLatest(for chapter: Chapter) -> QuizLaunch? {
        guard let latest = latestDraft(for: chapter.id) else { return nil }
        return .resume(draftID: latest.id)
    }

    private func makeSession(for chapter: Chapter) async -> ChapterSession? {
        logger.debug("makeSession chapter='\(chapter.title, privacy: .public)'")
        rowErrors[chapter.id] = nil
        rowStates[chapter.id] = .loading

        do {
            guard let book = try await libraryStore.book(for: bookID) else {
                logger.error("makeSession book missing '\(self.bookID, privacy: .public)'")
                rowStates[chapter.id] = .failed("Book missing")
                rowErrors[chapter.id] = "Book file is missing."
                return nil
            }

            let text = try await epubBookCache.chapterText(for: book, chapter: chapter)
            logger.debug("makeSession extracted \(text.count, privacy: .public) chars for '\(chapter.title, privacy: .public)'")

            guard !text.isEmpty else {
                logger.error("makeSession empty text for '\(chapter.title, privacy: .public)'")
                rowStates[chapter.id] = .failed("Empty")
                rowErrors[chapter.id] = "Couldn't read this chapter."
                return nil
            }

            rowStates[chapter.id] = .loaded(text)
            return ChapterSession(
                bookID: bookID,
                bookTitle: bookTitle,
                chapterID: chapter.id,
                chapterTitle: chapter.title,
                chapterText: text
            )
        } catch {
            logger.error("makeSession failed for '\(chapter.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            rowStates[chapter.id] = .failed(error.localizedDescription)
            rowErrors[chapter.id] = "Couldn't read this chapter."
            return nil
        }
    }
}
