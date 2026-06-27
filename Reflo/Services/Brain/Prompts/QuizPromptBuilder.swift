import Foundation

struct QuizPromptBuilder: Sendable {
    private let template: String

    init(template: String) {
        self.template = template
    }

    init(bundle: Bundle, resourceName: String = "questions", fileExtension: String = "md") throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: fileExtension) else {
            throw LanguageModelError.decoding(message: "Missing prompt resource \(resourceName).\(fileExtension)")
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw LanguageModelError.decoding(message: "Prompt resource is not valid UTF-8.")
        }
        self.template = text
    }

    func messages(bookTitle: String, chapterText: String, numQuestions: Int) -> [ChatMessage] {
        let filled = template
            .replacingOccurrences(of: "{{BOOK_TITLE}}", with: bookTitle)
            .replacingOccurrences(of: "{{CHAPTER_TEXT}}", with: chapterText)
            .replacingOccurrences(of: "{{NUM_QUESTIONS}}", with: String(numQuestions))

        return [
            ChatMessage(
                role: .system,
                content: "You write multiple-choice quiz questions for a reading companion. Follow the instructions exactly and output only valid JSON."
            ),
            ChatMessage(role: .user, content: filled)
        ]
    }
}
