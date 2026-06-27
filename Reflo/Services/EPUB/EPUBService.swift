import EPUBKit
import Foundation

enum EPUBServiceError: Error, LocalizedError {
    case parseFailed
    case bookNotFound

    var errorDescription: String? {
        switch self {
        case .parseFailed:
            return "Couldn't read this book."
        case .bookNotFound:
            return "Book file is missing."
        }
    }
}

/// EPUBKit 0.5.0 API notes (Phase 0 spike):
/// - `EPUBDocument(url:)` parses via `EPUBParser`
/// - `document.tableOfContents` is a root node; chapters live in `subTable`
/// - Each TOC node: `label`, `id`, `item` (href string), `subTable`
/// - `document.contentDirectory` + manifest `path` resolves content files
/// - `document.spine.items` uses `idref` → manifest id
/// - `document.metadata.title` / `document.title` for Dublin Core title
struct EPUBService: Sendable {
    func title(from document: EPUBDocument) -> String {
        if let title = document.title, !title.isEmpty {
            return title
        }
        return "Untitled"
    }

    func chapters(from document: EPUBDocument) -> [Chapter] {
        let rootChildren = document.tableOfContents.subTable ?? []
        var tocChapters: [Chapter] = []
        for node in rootChildren {
            tocChapters.append(contentsOf: flattenTOC(node, depth: 0))
        }

        if !tocChapters.isEmpty {
            return dedupeChapters(tocChapters)
        }
        return spineFallbackChapters(from: document)
    }

    private func flattenTOC(_ node: EPUBTableOfContents, depth: Int) -> [Chapter] {
        var result: [Chapter] = []

        if let href = node.item, !href.isEmpty, !node.label.isEmpty {
            result.append(Chapter(
                id: stableID(for: href),
                title: node.label,
                href: href,
                depth: depth
            ))
        }

        for child in node.subTable ?? [] {
            result.append(contentsOf: flattenTOC(child, depth: depth + 1))
        }

        return result
    }

    private func dedupeChapters(_ chapters: [Chapter]) -> [Chapter] {
        var seen = Set<String>()
        return chapters.filter { chapter in
            let key = hrefFilePart(chapter.href)
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func spineFallbackChapters(from document: EPUBDocument) -> [Chapter] {
        document.spine.items.compactMap { spineItem in
            guard let manifestItem = document.manifest.items[spineItem.idref] else { return nil }
            guard isTextContent(manifestItem) else { return nil }
            let path = manifestItem.path
            let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return Chapter(
                id: stableID(for: path),
                title: filename,
                href: path,
                depth: 0
            )
        }
    }

    func isTextContent(_ manifestItem: EPUBManifestItem) -> Bool {
        if manifestItem.mediaType == .xHTML { return true }
        let path = manifestItem.path.lowercased()
        return path.hasSuffix(".xhtml") || path.hasSuffix(".html") || path.hasSuffix(".htm")
    }

    func hrefFilePart(_ href: String) -> String {
        href.split(separator: "#", maxSplits: 1).first.map(String.init) ?? href
    }

    func stableID(for href: String) -> String {
        hrefFilePart(href)
    }

    func spineIndex(for href: String, in document: EPUBDocument) -> Int? {
        let filePart = hrefFilePart(href)
        for (index, spineItem) in document.spine.items.enumerated() {
            guard let manifestItem = document.manifest.items[spineItem.idref] else { continue }
            if pathsMatch(manifestItem.path, filePart) {
                return index
            }
        }
        return nil
    }

    func contentURL(for manifestPath: String, in document: EPUBDocument) -> URL {
        document.contentDirectory.appendingPathComponent(manifestPath)
    }

    func manifestPath(for href: String, in document: EPUBDocument) -> String? {
        let filePart = hrefFilePart(href)
        if let exact = document.manifest.items.values.first(where: { $0.path == filePart }) {
            return exact.path
        }
        return document.manifest.items.values.first(where: {
            pathsMatch($0.path, filePart)
        })?.path
    }

    private func pathsMatch(_ manifestPath: String, _ hrefPath: String) -> Bool {
        manifestPath == hrefPath
            || manifestPath.hasSuffix(hrefPath)
            || hrefPath.hasSuffix(manifestPath)
    }
}
