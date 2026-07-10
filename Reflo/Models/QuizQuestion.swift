import Foundation

struct QuizQuestion: Identifiable, Sendable, Hashable {
    let id: String
    let prompt: String
    let options: [QuizQuestionOption]
    let bookExample: String
    let idea: String

    var choices: [String] { options.map(\.text) }

    var correctIndex: Int {
        options.firstIndex(where: \.isCorrect) ?? 0
    }

    init(
        id: String,
        prompt: String,
        options: [QuizQuestionOption],
        bookExample: String,
        idea: String
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.bookExample = bookExample
        self.idea = idea
    }

    init(
        id: String,
        prompt: String,
        choices: [String],
        correctIndex: Int,
        bookExample: String,
        idea: String,
        trapTypes: [TrapType?]? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.bookExample = bookExample
        self.idea = idea
        self.options = choices.enumerated().map { index, text in
            let isCorrect = index == correctIndex
            let trap = trapTypes?[index]
            return QuizQuestionOption(text: text, isCorrect: isCorrect, trapType: isCorrect ? nil : trap)
        }
    }
}
