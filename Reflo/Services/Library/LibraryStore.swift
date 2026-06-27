import Foundation

private let logger = AppLog.library

enum LibraryStoreError: Error, LocalizedError {
    case copyFailed
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .copyFailed:
            return "Couldn't add this book."
        case .accessDenied:
            return "Couldn't access the selected file."
        }
    }
}

actor LibraryStore {
    private let fileManager = FileManager.default

    var booksDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Books", isDirectory: true)
    }

    func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
    }

    func listBooks() throws -> [Book] {
        try ensureDirectoryExists()
        let urls = try fileManager.contentsOfDirectory(
            at: booksDirectory,
            includingPropertiesForKeys: nil
        )
        let books: [Book] = urls
            .filter { $0.pathExtension.lowercased() == "epub" }
            .map { url in
                let id = url.deletingPathExtension().lastPathComponent
                return Book(id: id, fileURL: url)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        logger.debug("listBooks found \(books.count, privacy: .public) epub(s) in \(self.booksDirectory.lastPathComponent, privacy: .public)")
        return books
    }

    func importBook(from sourceURL: URL) throws -> Book {
        logger.debug("importBook from '\(sourceURL.lastPathComponent, privacy: .public)'")
        try ensureDirectoryExists()

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard didAccess || sourceURL.isFileURL else {
            logger.error("importBook access denied for '\(sourceURL.lastPathComponent, privacy: .public)'")
            throw LibraryStoreError.accessDenied
        }

        let originalName = sourceURL.lastPathComponent
        var destinationURL = booksDirectory.appendingPathComponent(originalName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            let uuid = UUID().uuidString.prefix(8)
            destinationURL = booksDirectory.appendingPathComponent("\(uuid)_\(originalName)")
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            logger.error("importBook copy failed: \(error.localizedDescription, privacy: .public)")
            throw LibraryStoreError.copyFailed
        }

        let id = destinationURL.deletingPathExtension().lastPathComponent
        logger.debug("importBook copied as id='\(id, privacy: .public)'")
        return Book(id: id, fileURL: destinationURL)
    }

    func book(for id: String) throws -> Book? {
        try listBooks().first { $0.id == id }
    }
}
