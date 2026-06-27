import Foundation

struct QuizQuestion: Identifiable, Sendable, Hashable {
    let id: String
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let bookExample: String
}
