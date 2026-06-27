import Foundation

private let logger = AppLog.brain

struct ModelBrainServices: BrainServices {
    private let client: any LanguageModelClient
    private let config: LLMConfiguration
    private let promptBuilder: QuizPromptBuilder
    private let fallback: any BrainServices

    init(
        client: any LanguageModelClient,
        config: LLMConfiguration,
        promptBuilder: QuizPromptBuilder,
        fallback: any BrainServices = StubBrainServices()
    ) {
        self.client = client
        self.config = config
        self.promptBuilder = promptBuilder
        self.fallback = fallback
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

    func mend(question: QuizQuestion) async throws -> String {
        try await fallback.mend(question: question)
    }

    func secondExample(for question: QuizQuestion) async throws -> String {
        try await fallback.secondExample(for: question)
    }

    func reply(narration: String, chapterText: String) async throws -> NarrationReply {
        try await fallback.reply(narration: narration, chapterText: chapterText)
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
