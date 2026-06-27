import SwiftUI

private let logger = AppLog.library

@MainActor
final class ChaptersViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[Chapter]> = .idle
    @Published private(set) var bookTitle = ""
    @Published var rowStates: [String: LoadState<String>] = [:]
    @Published var rowErrors: [String: String] = [:]

    private let bookID: String
    private let libraryStore: LibraryStore
    private let epubBookCache: EPUBBookCache

    init(bookID: String, libraryStore: LibraryStore, epubBookCache: EPUBBookCache) {
        self.bookID = bookID
        self.libraryStore = libraryStore
        self.epubBookCache = epubBookCache
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
        } catch {
            logger.error("ChaptersViewModel.load failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(error.localizedDescription)
        }
    }

    func startQuiz(for chapter: Chapter) async -> ChapterSession? {
        logger.debug("startQuiz chapter='\(chapter.title, privacy: .public)'")
        rowErrors[chapter.id] = nil
        rowStates[chapter.id] = .loading

        do {
            guard let book = try await libraryStore.book(for: bookID) else {
                logger.error("startQuiz book missing '\(self.bookID, privacy: .public)'")
                rowStates[chapter.id] = .failed("Book missing")
                rowErrors[chapter.id] = "Book file is missing."
                return nil
            }

            let text = try await epubBookCache.chapterText(for: book, chapter: chapter)
            logger.debug("startQuiz extracted \(text.count, privacy: .public) chars for '\(chapter.title, privacy: .public)'")

            guard !text.isEmpty else {
                logger.error("startQuiz empty text for '\(chapter.title, privacy: .public)'")
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
            logger.error("startQuiz failed for '\(chapter.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            rowStates[chapter.id] = .failed(error.localizedDescription)
            rowErrors[chapter.id] = "Couldn't read this chapter."
            return nil
        }
    }
}
