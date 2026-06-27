import EPUBKit
import Foundation

struct ChapterTextExtractor: Sendable {
    let epubService: EPUBService

    func extractText(
        for chapter: Chapter,
        chapters: [Chapter],
        document: EPUBDocument
    ) throws -> String {
        guard let startIndex = epubService.spineIndex(for: chapter.href, in: document) else {
            return ""
        }

        let endIndex = endSpineIndex(
            currentChapter: chapter,
            allChapters: chapters,
            document: document,
            startIndex: startIndex
        )

        var parts: [String] = []
        for index in startIndex...endIndex {
            guard index < document.spine.items.count else { break }
            let spineItem = document.spine.items[index]
            guard let manifestItem = document.manifest.items[spineItem.idref] else { continue }
            guard epubService.isTextContent(manifestItem) else { continue }

            let fileURL = epubService.contentURL(for: manifestItem.path, in: document)
            guard let data = try? Data(contentsOf: fileURL),
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                continue
            }
            let plain = HTMLPlainText.strip(html)
            if !plain.isEmpty {
                parts.append(plain)
            }
        }

        return parts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func endSpineIndex(
        currentChapter: Chapter,
        allChapters: [Chapter],
        document: EPUBDocument,
        startIndex: Int
    ) -> Int {
        guard let currentPosition = allChapters.firstIndex(where: { $0.id == currentChapter.id }) else {
            return document.spine.items.count - 1
        }

        let remaining = allChapters.dropFirst(currentPosition + 1)
        for nextChapter in remaining {
            if let nextIndex = epubService.spineIndex(for: nextChapter.href, in: document), nextIndex > startIndex {
                return max(startIndex, nextIndex - 1)
            }
        }

        return document.spine.items.count - 1
    }
}

enum HTMLPlainText {
    static func strip(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "(?s)<script.*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<style.*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeBasicEntities(text)
        text = text.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeBasicEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
