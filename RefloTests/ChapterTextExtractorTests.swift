import EPUBKit
import XCTest
@testable import Reflo

final class ChapterTextExtractorTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/sample.epub")
    }

    func testExtractsNonEmptyTextForFirstChapter() throws {
        let url = fixtureURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing Fixtures/sample.epub")

        guard let document = EPUBDocument(url: url) else {
            XCTFail("Failed to parse sample.epub")
            return
        }

        let epubService = EPUBService()
        let chapters = epubService.chapters(from: document)
        XCTAssertFalse(chapters.isEmpty, "Expected at least one chapter")

        let extractor = ChapterTextExtractor(epubService: epubService)
        let text = try extractor.extractText(
            for: chapters[0],
            chapters: chapters,
            document: document
        )

        XCTAssertGreaterThan(text.count, 100, "Expected substantial chapter text")
    }

    func testLastChapterExtractsThroughEndOfSpine() throws {
        let url = fixtureURL
        guard let document = EPUBDocument(url: url) else {
            XCTFail("Failed to parse sample.epub")
            return
        }

        let epubService = EPUBService()
        let chapters = epubService.chapters(from: document)
        guard let lastChapter = chapters.last else {
            XCTFail("No chapters")
            return
        }

        let extractor = ChapterTextExtractor(epubService: epubService)
        let text = try extractor.extractText(
            for: lastChapter,
            chapters: chapters,
            document: document
        )

        XCTAssertFalse(text.isEmpty, "Last chapter should extract through end of spine")
    }

    func testEPUBServiceFindsChaptersOrSpineFallback() throws {
        let url = fixtureURL
        guard let document = EPUBDocument(url: url) else {
            XCTFail("Failed to parse sample.epub")
            return
        }

        let epubService = EPUBService()
        let chapters = epubService.chapters(from: document)
        XCTAssertFalse(chapters.isEmpty)
        XCTAssertFalse(epubService.title(from: document).isEmpty)
    }
}
