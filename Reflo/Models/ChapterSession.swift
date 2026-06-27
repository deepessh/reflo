import Foundation

struct ChapterSession: Hashable, Sendable {
    let bookID: String
    let bookTitle: String
    let chapterID: String
    let chapterTitle: String
    let chapterText: String
}
