import SwiftUI

struct AppEnvironment {
    let libraryStore: LibraryStore
    let epubBookCache: EPUBBookCache
    let brain: any BrainServices
    let llmSettingsRepository: LLMSettingsRepository
    let modelCatalogClient: ModelCatalogClient

    static let live: AppEnvironment = {
        let repository = LLMSettingsRepository()
        let transport = NoRedirectURLSessionTransport()
        let catalogClient = ModelCatalogClient(transport: transport)

        let quizPromptBuilderResult: Result<QuizPromptBuilder, Error> = Result {
            try QuizPromptBuilder(bundle: .main, resourceName: "questions", fileExtension: "md")
        }

        let brain = ConfigurableBrainServices(
            repository: repository,
            transport: transport,
            quizPromptBuilderResult: quizPromptBuilderResult
        )

        return AppEnvironment(
            libraryStore: LibraryStore(),
            epubBookCache: EPUBBookCache(),
            brain: brain,
            llmSettingsRepository: repository,
            modelCatalogClient: catalogClient
        )
    }()
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.live
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

private struct SpeechTranscriberKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = SpeechTranscriber()
}

extension EnvironmentValues {
    var speechTranscriber: SpeechTranscriber {
        get { self[SpeechTranscriberKey.self] }
        set { self[SpeechTranscriberKey.self] = newValue }
    }
}
