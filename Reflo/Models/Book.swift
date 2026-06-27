import Foundation

struct Book: Identifiable, Sendable, Hashable {
    let id: String
    let fileURL: URL
    var title: String

    init(id: String, fileURL: URL, title: String? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.title = title ?? id
    }
}
