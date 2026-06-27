import Foundation

enum AppRoute: Hashable {
    case chapters(bookID: String)
    case quiz(ChapterSession)
    case narrate(ChapterSession)
    case feedback(ChapterSession, narrationText: String)
}
