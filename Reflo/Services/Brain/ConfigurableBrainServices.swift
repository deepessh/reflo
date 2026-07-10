import Foundation

struct ConfigurableBrainServices: BrainServices {
    private let repository: LLMSettingsRepository
    private let transport: any HTTPTransport
    private let quizPromptBuilderResult: Result<QuizPromptBuilder, Error>

    init(
        repository: LLMSettingsRepository,
        transport: any HTTPTransport,
        quizPromptBuilderResult: Result<QuizPromptBuilder, Error>
    ) {
        self.repository = repository
        self.transport = transport
        self.quizPromptBuilderResult = quizPromptBuilderResult
    }

    func makeQuiz(bookTitle: String, chapterText: String) async throws -> [QuizQuestion] {
        try await withDelegate { try await $0.makeQuiz(bookTitle: bookTitle, chapterText: chapterText) }
    }

    func mend(question: QuizQuestion, pickedChoiceIndex: Int, bookTitle: String, chapterTitle: String) async throws -> String {
        try await withDelegate {
            try await $0.mend(
                question: question,
                pickedChoiceIndex: pickedChoiceIndex,
                bookTitle: bookTitle,
                chapterTitle: chapterTitle
            )
        }
    }

    func secondExample(for question: QuizQuestion, pickedChoiceIndex: Int) async throws -> String {
        try await withDelegate { try await $0.secondExample(for: question, pickedChoiceIndex: pickedChoiceIndex) }
    }

    func reply(narration: String, chapterText: String) async throws -> NarrationReply {
        try await withDelegate { try await $0.reply(narration: narration, chapterText: chapterText) }
    }

    private func withDelegate<T>(_ operation: (ModelBrainServices) async throws -> T) async throws -> T {
        let delegate = try await makeDelegate()
        return try await operation(delegate)
    }

    private func makeDelegate() async throws -> ModelBrainServices {
        guard let snapshot = await repository.currentSnapshot() else {
            throw LanguageModelError.notConfigured
        }

        let promptBuilder: QuizPromptBuilder
        switch quizPromptBuilderResult {
        case .success(let builder):
            promptBuilder = builder
        case .failure(let error):
            throw error
        }

        let client = OpenAICompatibleClient(configuration: snapshot.configuration, transport: transport)
        return ModelBrainServices(
            client: client,
            config: snapshot.configuration,
            promptBuilder: promptBuilder
        )
    }
}
