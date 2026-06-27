import Foundation

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
        return urls
            .filter { $0.pathExtension.lowercased() == "epub" }
            .map { url in
                let id = url.deletingPathExtension().lastPathComponent
                return Book(id: id, fileURL: url)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func importBook(from sourceURL: URL) throws -> Book {
        try ensureDirectoryExists()

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard didAccess || sourceURL.isFileURL else {
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
            throw LibraryStoreError.copyFailed
        }

        let id = destinationURL.deletingPathExtension().lastPathComponent
        return Book(id: id, fileURL: destinationURL)
    }

    func book(for id: String) throws -> Book? {
        try listBooks().first { $0.id == id }
    }
}
