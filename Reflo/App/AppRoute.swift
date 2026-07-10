import Foundation

enum AppRoute: Hashable {
    case chapters(bookID: String)
    case quizzes
    case quizFlow(QuizLaunch)
    case attemptDetail(id: UUID)
    case quiz(ChapterSession)
    case narrate(ChapterSession)
    case feedback(ChapterSession, narrationText: String)
}
