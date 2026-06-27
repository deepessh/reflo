import Foundation

protocol QuizGenerating: Sendable {
    func makeQuiz(chapterText: String) async throws -> [QuizQuestion]
}

protocol MendingParagraphProviding: Sendable {
    func mend(question: QuizQuestion) async throws -> String
}

protocol SecondExampleProviding: Sendable {
    func secondExample(for question: QuizQuestion) async throws -> String
}

protocol NarrationReplying: Sendable {
    func reply(narration: String, chapterText: String) async throws -> NarrationReply
}

typealias BrainServices = QuizGenerating & MendingParagraphProviding & SecondExampleProviding & NarrationReplying
