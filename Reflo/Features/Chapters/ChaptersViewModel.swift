import SwiftUI

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
        loadState = .loading
        do {
            guard let book = try await libraryStore.book(for: bookID) else {
                loadState = .failed("Book file is missing.")
                return
            }
            bookTitle = try await epubBookCache.title(for: book)
            let chapters = try await epubBookCache.chapters(for: book)
            loadState = .loaded(chapters)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func startQuiz(for chapter: Chapter) async -> ChapterSession? {
        rowErrors[chapter.id] = nil
        rowStates[chapter.id] = .loading

        do {
            guard let book = try await libraryStore.book(for: bookID) else {
                rowStates[chapter.id] = .failed("Book missing")
                rowErrors[chapter.id] = "Book file is missing."
                return nil
            }

            let text = try await epubBookCache.chapterText(for: book, chapter: chapter)

            #if DEBUG
            let preview = String(text.prefix(200))
            print("[Reflo] Extracted \(text.count) chars for '\(chapter.title)': \(preview)")
            #endif

            guard !text.isEmpty else {
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
            rowStates[chapter.id] = .failed(error.localizedDescription)
            rowErrors[chapter.id] = "Couldn't read this chapter."
            return nil
        }
    }
}
