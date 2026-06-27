import Foundation

struct QuizResponseDTO: Decodable {
    let coreIdeas: [CoreIdeaDTO]?
    let questions: [QuestionDTO]

    enum CodingKeys: String, CodingKey {
        case coreIdeas = "core_ideas"
        case questions
    }
}

struct CoreIdeaDTO: Decodable {
    let idea: String
    let overturns: String
}

struct QuestionDTO: Decodable {
    let idea: String?
    let bookExample: String
    let stem: String
    let options: [OptionDTO]

    enum CodingKeys: String, CodingKey {
        case idea
        case bookExample = "book_example"
        case stem
        case options
    }
}

struct OptionDTO: Decodable {
    let text: String
    let correct: Bool
    let misconception: String?
    let depth: String?
    let note: String?
}

enum QuizResponseParser {
    static func parseQuestions(from rawText: String) throws -> [QuizQuestion] {
        let dto = try decodeDTO(from: rawText)
        return try mapToQuizQuestions(dto)
    }

    private static func decodeDTO(from rawText: String) throws -> QuizResponseDTO {
        let candidates = jsonCandidates(from: rawText)
        var lastError: Error?

        for candidate in candidates {
            do {
                let data = Data(candidate.utf8)
                return try JSONDecoder().decode(QuizResponseDTO.self, from: data)
            } catch {
                lastError = error
            }
        }

        let message = (lastError as? DecodingError).map(describeDecodingError) ?? lastError?.localizedDescription ?? "Invalid JSON"
        throw LanguageModelError.decoding(message: message)
    }

    private static func mapToQuizQuestions(_ dto: QuizResponseDTO) throws -> [QuizQuestion] {
        guard !dto.questions.isEmpty else {
            throw LanguageModelError.decoding(message: "No questions in response.")
        }

        return try dto.questions.enumerated().map { index, question in
            try mapQuestion(question, index: index)
        }
    }

    private static func mapQuestion(_ question: QuestionDTO, index: Int) throws -> QuizQuestion {
        guard question.options.count >= 2 else {
            throw LanguageModelError.decoding(message: "Question \(index + 1) needs at least two options.")
        }

        let correctIndices = question.options.enumerated().filter(\.element.correct).map(\.offset)
        guard correctIndices.count == 1, let correctIndexBeforeShuffle = correctIndices.first else {
            throw LanguageModelError.decoding(message: "Question \(index + 1) must have exactly one correct option.")
        }

        var indexedOptions = question.options.enumerated().map { ($0.offset, $0.element) }
        indexedOptions.shuffle()

        let choices = indexedOptions.map(\.1.text)
        guard let newCorrectIndex = indexedOptions.firstIndex(where: { $0.0 == correctIndexBeforeShuffle }) else {
            throw LanguageModelError.decoding(message: "Question \(index + 1) lost its correct option during shuffle.")
        }

        return QuizQuestion(
            id: "q\(index + 1)",
            prompt: question.stem,
            choices: choices,
            correctIndex: newCorrectIndex,
            bookExample: question.bookExample
        )
    }

    private static func jsonCandidates(from rawText: String) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []

        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return }
            candidates.append(trimmed)
        }

        append(rawText)
        if let stripped = stripMarkdownFences(from: rawText) {
            append(stripped)
        }

        if let extracted = extractFirstJSONObject(from: rawText) {
            append(extracted)
        }

        if let fenced = stripMarkdownFences(from: rawText),
           let extracted = extractFirstJSONObject(from: fenced) {
            append(extracted)
        }

        return candidates
    }

    private static func stripMarkdownFences(from text: String) -> String? {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if working.hasPrefix("```") {
            working = working.replacingOccurrences(of: "```json", with: "")
            working = working.replacingOccurrences(of: "```", with: "")
            working = working.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return working == text.trimmingCharacters(in: .whitespacesAndNewlines) ? nil : working
    }

    private static func extractFirstJSONObject(from text: String) -> String? {
        let chars = Array(text)
        var depth = 0
        var start: Int?
        var inString = false
        var isEscaped = false

        for (index, char) in chars.enumerated() {
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }

            switch char {
            case "\"":
                inString = true
            case "{":
                if depth == 0 {
                    start = index
                }
                depth += 1
            case "}":
                if depth > 0 {
                    depth -= 1
                    if depth == 0, let start {
                        return String(chars[start ... index])
                    }
                }
            default:
                break
            }
        }

        return nil
    }

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing field '\(key.stringValue)'."
        case .typeMismatch(_, let context):
            return "Unexpected type at '\(context.codingPath.map(\.stringValue).joined(separator: "."))'."
        case .valueNotFound(_, let context):
            return "Missing value at '\(context.codingPath.map(\.stringValue).joined(separator: "."))'."
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return error.localizedDescription
        }
    }
}
