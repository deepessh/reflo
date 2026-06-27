import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published private(set) var loadState: LoadState<[Book]> = .idle
    @Published var titleLoadStates: [String: LoadState<String>] = [:]
    @Published var importError: String?
    @Published var isImporting = false

    private let libraryStore: LibraryStore
    private let epubBookCache: EPUBBookCache

    init(libraryStore: LibraryStore, epubBookCache: EPUBBookCache) {
        self.libraryStore = libraryStore
        self.epubBookCache = epubBookCache
    }

    func loadBooks() async {
        loadState = .loading
        do {
            let loaded = try await libraryStore.listBooks()
            books = loaded
            loadState = .loaded(loaded)
            for book in loaded {
                await loadTitle(for: book)
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func importBook(from url: URL) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }

        do {
            let book = try await libraryStore.importBook(from: url)
            await loadBooks()
            await loadTitle(for: book)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func loadTitle(for book: Book) async {
        titleLoadStates[book.id] = .loading
        do {
            let title = try await epubBookCache.title(for: book)
            titleLoadStates[book.id] = .loaded(title)
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                books[index].title = title
            }
        } catch {
            titleLoadStates[book.id] = .failed(error.localizedDescription)
        }
    }
}
