import EPUBKit
import Foundation

private let logger = AppLog.epub

actor EPUBBookCache {
    private var documents: [String: EPUBDocument] = [:]
    private let epubService = EPUBService()

    func title(for book: Book) async throws -> String {
        let document = try await document(for: book)
        return epubService.title(from: document)
    }

    func chapters(for book: Book) async throws -> [Chapter] {
        let document = try await document(for: book)
        let chapters = epubService.chapters(from: document)
        logger.debug("chapters for '\(book.id, privacy: .public)' -> \(chapters.count, privacy: .public)")
        return chapters
    }

    func chapterText(for book: Book, chapter: Chapter) async throws -> String {
        let document = try await document(for: book)
        let chapters = epubService.chapters(from: document)
        let extractor = ChapterTextExtractor(epubService: epubService)
        let text = try extractor.extractText(for: chapter, chapters: chapters, document: document)
        logger.debug("chapterText '\(chapter.title, privacy: .public)' -> \(text.count, privacy: .public) chars")
        return text
    }

    func document(for book: Book) async throws -> EPUBDocument {
        if let cached = documents[book.id] {
            logger.debug("document cache hit for '\(book.id, privacy: .public)'")
            return cached
        }
        guard FileManager.default.fileExists(atPath: book.fileURL.path) else {
            logger.error("document file missing for '\(book.id, privacy: .public)'")
            throw EPUBServiceError.bookNotFound
        }
        guard let document = EPUBDocument(url: book.fileURL) else {
            logger.error("document parse failed for '\(book.id, privacy: .public)'")
            throw EPUBServiceError.parseFailed
        }
        documents[book.id] = document
        logger.debug("document parsed and cached for '\(book.id, privacy: .public)'")
        return document
    }

    func clearAll() {
        documents.removeAll()
    }
}
