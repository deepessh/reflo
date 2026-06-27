import SwiftUI

struct AppEnvironment {
    let libraryStore: LibraryStore
    let epubBookCache: EPUBBookCache
    let brain: any BrainServices

    static let live: AppEnvironment = {
        let fallback = StubBrainServices()

        guard let config = LLMConfiguration.load(),
              let promptBuilder = try? QuizPromptBuilder(bundle: .main, resourceName: "questions", fileExtension: "md")
        else {
            return AppEnvironment(
                libraryStore: LibraryStore(),
                epubBookCache: EPUBBookCache(),
                brain: fallback
            )
        }

        let client = OpenAICompatibleClient(configuration: config)
        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: promptBuilder,
            fallback: fallback
        )

        return AppEnvironment(
            libraryStore: LibraryStore(),
            epubBookCache: EPUBBookCache(),
            brain: brain
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
