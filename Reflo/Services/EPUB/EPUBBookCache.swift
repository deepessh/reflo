import EPUBKit
import Foundation

actor EPUBBookCache {
    private var documents: [String: EPUBDocument] = [:]
    private let epubService = EPUBService()

    func title(for book: Book) async throws -> String {
        let document = try await document(for: book)
        return epubService.title(from: document)
    }

    func chapters(for book: Book) async throws -> [Chapter] {
        let document = try await document(for: book)
        return epubService.chapters(from: document)
    }

    func chapterText(for book: Book, chapter: Chapter) async throws -> String {
        let document = try await document(for: book)
        let chapters = epubService.chapters(from: document)
        let extractor = ChapterTextExtractor(epubService: epubService)
        return try extractor.extractText(for: chapter, chapters: chapters, document: document)
    }

    func document(for book: Book) async throws -> EPUBDocument {
        if let cached = documents[book.id] {
            return cached
        }
        guard FileManager.default.fileExists(atPath: book.fileURL.path) else {
            throw EPUBServiceError.bookNotFound
        }
        guard let document = EPUBDocument(url: book.fileURL) else {
            throw EPUBServiceError.parseFailed
        }
        documents[book.id] = document
        return document
    }

    func clearAll() {
        documents.removeAll()
    }
}
