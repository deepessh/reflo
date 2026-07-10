import Foundation

struct QuizQuestionOption: Codable, Sendable, Hashable {
    let text: String
    let isCorrect: Bool
    let trapType: TrapType?

    init(text: String, isCorrect: Bool, trapType: TrapType?) {
        self.text = text
        self.isCorrect = isCorrect
        self.trapType = trapType
    }
}

struct CapturedQuizOption: Codable, Sendable, Hashable {
    let text: String
    let isCorrect: Bool
    let trapType: TrapType?

    init(text: String, isCorrect: Bool, trapType: TrapType?) {
        self.text = text
        self.isCorrect = isCorrect
        self.trapType = trapType
    }

    init(from option: QuizQuestionOption) {
        self.init(text: option.text, isCorrect: option.isCorrect, trapType: option.trapType)
    }
}

struct CapturedQuizQuestion: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let prompt: String
    let options: [CapturedQuizOption]
    let bookExample: String
    let idea: String

    init(from question: QuizQuestion) {
        id = question.id
        prompt = question.prompt
        options = question.options.map(CapturedQuizOption.init)
        bookExample = question.bookExample
        idea = question.idea
    }

    init(id: String, prompt: String, options: [CapturedQuizOption], bookExample: String, idea: String) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.bookExample = bookExample
        self.idea = idea
    }
}

struct CapturedChapterSnapshot: Codable, Sendable, Hashable {
    let bookID: String
    let bookTitle: String
    let chapterID: String
    let chapterTitle: String
    let chapterText: String

    init(session: ChapterSession) {
        bookID = session.bookID
        bookTitle = session.bookTitle
        chapterID = session.chapterID
        chapterTitle = session.chapterTitle
        chapterText = session.chapterText
    }

    init(bookID: String, bookTitle: String, chapterID: String, chapterTitle: String, chapterText: String) {
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.chapterID = chapterID
        self.chapterTitle = chapterTitle
        self.chapterText = chapterText
    }
}

struct CapturedAnswer: Codable, Sendable, Hashable {
    let selectedIndex: Int
}

struct CapturedQuestionState: Codable, Sendable, Hashable, Identifiable {
    let question: CapturedQuizQuestion
    var answer: CapturedAnswer?
    var mendingText: String?
    var secondExampleText: String?
    var secondExampleFetchFailed: Bool

    var id: String { question.id }

    init(question: CapturedQuizQuestion) {
        self.question = question
        answer = nil
        mendingText = nil
        secondExampleText = nil
        secondExampleFetchFailed = false
    }

    init(from question: QuizQuestion) {
        self.init(question: CapturedQuizQuestion(from: question))
    }
}
