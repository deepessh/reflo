import Foundation

private let logger = AppLog.brain

struct ModelBrainServices: BrainServices {
    private let client: any LanguageModelClient
    private let config: LLMConfiguration
    private let promptBuilder: QuizPromptBuilder

    init(
        client: any LanguageModelClient,
        config: LLMConfiguration,
        promptBuilder: QuizPromptBuilder
    ) {
        self.client = client
        self.config = config
        self.promptBuilder = promptBuilder
    }

    func makeQuiz(bookTitle: String, chapterText: String) async throws -> [QuizQuestion] {
        logger.debug("makeQuiz book='\(bookTitle, privacy: .public)' chapterChars=\(chapterText.count, privacy: .public) numQuestions=\(config.numQuestions, privacy: .public)")

        let messages = promptBuilder.messages(
            bookTitle: bookTitle,
            chapterText: chapterText,
            numQuestions: config.numQuestions
        )

        let request = CompletionRequest(
            messages: messages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            responseFormat: config.useJSONResponseFormat ? .jsonObject : .text
        )

        var lastError: Error?

        for attempt in 0 ..< 2 {
            do {
                let response = try await client.complete(request)

                if response.finishReason == "length" {
                    throw LanguageModelError.truncated
                }

                let questions = try QuizResponseParser.parseQuestions(from: response.text)
                logger.debug("makeQuiz parsed \(questions.count, privacy: .public) questions on attempt \(attempt, privacy: .public)")
                return questions
            } catch {
                lastError = error
                let shouldRetry = attempt == 0 && isRetryable(error)
                if shouldRetry {
                    logger.debug("makeQuiz attempt \(attempt, privacy: .public) failed (retrying): \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("makeQuiz failed on attempt \(attempt, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    throw error
                }
            }
        }

        logger.error("makeQuiz exhausted retries: \(lastError?.localizedDescription ?? "unknown", privacy: .public)")
        throw lastError ?? LanguageModelError.emptyResponse
    }

    func mend(question: QuizQuestion, pickedChoiceIndex: Int, bookTitle: String, chapterTitle: String) async throws -> String {
        let correct = question.choices.indices.contains(question.correctIndex)
            ? question.choices[question.correctIndex]
            : ""
        let picked = question.choices.indices.contains(pickedChoiceIndex)
            ? question.choices[pickedChoiceIndex]
            : "(no answer recorded)"
        logger.debug("mend idea='\(question.idea, privacy: .public)' picked=\(pickedChoiceIndex, privacy: .public)")

        let template = try loadTemplate("mending")

        let choicesText = question.choices.joined(separator: "\n")
        let filled = template
            .components(separatedBy: .newlines)
            .filter { !$0.contains("{{misconception_label}}") }
            .joined(separator: "\n")
            .replacingOccurrences(of: "{{book_title}}", with: bookTitle)
            .replacingOccurrences(of: "{{chapter_title}}", with: chapterTitle)
            .replacingOccurrences(of: "{{question_stem}}", with: question.prompt)
            .replacingOccurrences(of: "{{choices}}", with: choicesText)
            .replacingOccurrences(of: "{{correct_choice}}", with: correct)
            .replacingOccurrences(of: "{{chosen_wrong_choice}}", with: picked)
            .replacingOccurrences(of: "{{book_example}}", with: question.bookExample)

        let messages = [
            ChatMessage(
                role: .system,
                content: "You are a gentle corrector for a reading companion. Follow the instructions exactly and return only the paragraph, no preamble."
            ),
            ChatMessage(role: .user, content: filled)
        ]

        let request = CompletionRequest(
            messages: messages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            responseFormat: .text
        )

        var lastError: Error?
        for attempt in 0 ..< 2 {
            do {
                let response = try await client.complete(request)

                if response.finishReason == "length" {
                    throw LanguageModelError.truncated
                }

                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    throw LanguageModelError.emptyResponse
                }

                logger.debug("mend received \(text.count, privacy: .public) chars on attempt \(attempt, privacy: .public)")
                return text
            } catch {
                lastError = error
                if attempt == 0 && isRetryable(error) {
                    logger.debug("mend attempt \(attempt, privacy: .public) failed (retrying): \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("mend failed on attempt \(attempt, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    break
                }
            }
        }

        logger.error("mend exhausted retries: \(lastError?.localizedDescription ?? "unknown", privacy: .public)")
        throw lastError ?? LanguageModelError.emptyResponse
    }

    func secondExample(for question: QuizQuestion, pickedChoiceIndex: Int) async throws -> String {
        let correct = question.choices.indices.contains(question.correctIndex)
            ? question.choices[question.correctIndex]
            : ""
        let picked = question.choices.indices.contains(pickedChoiceIndex)
            ? question.choices[pickedChoiceIndex]
            : "(no answer recorded)"
        logger.debug("secondExample idea='\(question.idea, privacy: .public)' picked=\(pickedChoiceIndex, privacy: .public)")

        let template = try loadTemplate("second-example-prompt")

        let filled = template
            .replacingOccurrences(of: "{{IDEA}}", with: question.idea)
            .replacingOccurrences(of: "{{BOOK_EXAMPLE}}", with: question.bookExample)
            .replacingOccurrences(of: "{{QUESTION}}", with: question.prompt)
            .replacingOccurrences(of: "{{CORRECT_CHOICE}}", with: correct)
            .replacingOccurrences(of: "{{USER_CHOICE}}", with: picked)

        let messages = [
            ChatMessage(
                role: .system,
                content: "You write a single second example for a reading companion, to sit beside the book's own example. Follow the instructions exactly and output only valid JSON."
            ),
            ChatMessage(role: .user, content: filled)
        ]

        let request = CompletionRequest(
            messages: messages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            responseFormat: config.useJSONResponseFormat ? .jsonObject : .text
        )

        struct MappingPair: Decodable {
            let book: String
            let new: String
        }

        struct SecondExampleDTO: Decodable {
            let example: String
            let bridge: String
            let mapping: [MappingPair]?
        }

        func decodeSecondExample(from text: String) throws -> SecondExampleDTO {
            let decoder = JSONDecoder()
            for candidate in QuizResponseParser.jsonCandidates(from: text) {
                if let dto = try? decoder.decode(SecondExampleDTO.self, from: Data(candidate.utf8)) {
                    return dto
                }
            }
            throw LanguageModelError.decoding(message: "Couldn't read the second example.")
        }

        var lastError: Error?
        for attempt in 0 ..< 2 {
            do {
                let response = try await client.complete(request)

                if response.finishReason == "length" {
                    throw LanguageModelError.truncated
                }

                let dto = try decodeSecondExample(from: response.text)
                if let mapping = dto.mapping, !mapping.isEmpty {
                    logger.debug("secondExample mapping pairs=\(mapping.count, privacy: .public)")
                }
                return [dto.example, dto.bridge].joined(separator: "\n\n")
            } catch {
                lastError = error
                if attempt == 0 && isRetryable(error) {
                    logger.debug("secondExample attempt \(attempt, privacy: .public) failed (retrying): \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("secondExample failed on attempt \(attempt, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    break
                }
            }
        }

        logger.error("secondExample exhausted retries: \(lastError?.localizedDescription ?? "unknown", privacy: .public)")
        throw lastError ?? LanguageModelError.emptyResponse
    }

    func reply(narration: String, chapterText: String) async throws -> NarrationReply {
        logger.debug("reply narrationChars=\(narration.count, privacy: .public) chapterChars=\(chapterText.count, privacy: .public)")

        let template = try loadTemplate("narration-reply")

        let filled = template
            .replacingOccurrences(of: "{{CHAPTER_TEXT}}", with: chapterText)
            .replacingOccurrences(of: "{{NARRATION_TRANSCRIPT}}", with: narration)

        let messages = [
            ChatMessage(
                role: .system,
                content: "You are the voice of a reading companion. Follow the instructions exactly and return only the spoken reply, no preamble."
            ),
            ChatMessage(role: .user, content: filled)
        ]

        let request = CompletionRequest(
            messages: messages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            responseFormat: .text
        )

        var lastError: Error?
        for attempt in 0 ..< 2 {
            do {
                let response = try await client.complete(request)

                if response.finishReason == "length" {
                    throw LanguageModelError.truncated
                }

                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    throw LanguageModelError.emptyResponse
                }

                logger.debug("reply received \(text.count, privacy: .public) chars on attempt \(attempt, privacy: .public)")
                return NarrationReply(text: text)
            } catch {
                lastError = error
                if attempt == 0 && isRetryable(error) {
                    logger.debug("reply attempt \(attempt, privacy: .public) failed (retrying): \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("reply failed on attempt \(attempt, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    break
                }
            }
        }

        logger.error("reply exhausted retries: \(lastError?.localizedDescription ?? "unknown", privacy: .public)")
        throw lastError ?? LanguageModelError.emptyResponse
    }

    private func loadTemplate(_ resource: String) throws -> String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md") else {
            throw LanguageModelError.missingPromptResource(name: "\(resource).md")
        }
        let data = try Data(contentsOf: url)
        guard let template = String(data: data, encoding: .utf8) else {
            throw LanguageModelError.decoding(message: "Prompt resource \(resource).md is not valid UTF-8.")
        }
        return template
    }

    private func isRetryable(_ error: Error) -> Bool {
        switch error {
        case LanguageModelError.decoding, LanguageModelError.truncated, LanguageModelError.emptyResponse:
            return true
        default:
            return false
        }
    }
}
