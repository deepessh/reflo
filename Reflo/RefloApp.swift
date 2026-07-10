import SwiftUI

@main
struct RefloApp: App {
    @State private var path = NavigationPath()
    @StateObject private var speechTranscriber = SpeechTranscriber()
    private let environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                LibraryView(
                    viewModel: LibraryViewModel(
                        libraryStore: environment.libraryStore,
                        epubBookCache: environment.epubBookCache
                    )
                )
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
            }
            .environment(\.appEnvironment, environment)
            .environment(\.speechTranscriber, speechTranscriber)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .chapters(let bookID):
            ChaptersView(
                bookID: bookID,
                path: $path,
                viewModel: ChaptersViewModel(
                    bookID: bookID,
                    libraryStore: environment.libraryStore,
                    epubBookCache: environment.epubBookCache,
                    auditLogStore: environment.auditLogStore
                )
            )
        case .quizzes:
            QuizzesView(
                path: $path,
                viewModel: QuizzesViewModel(store: environment.auditLogStore)
            )
        case .quizFlow(let launch):
            QuizAttemptFlowView(
                path: $path,
                viewModel: QuizAttemptFlowViewModel(
                    launch: launch,
                    brain: environment.brain,
                    lifecycle: QuizDraftLifecycle(store: environment.auditLogStore),
                    transcriber: speechTranscriber
                )
            )
        case .attemptDetail(let id):
            AttemptDetailView(
                viewModel: AttemptDetailViewModel(
                    store: environment.auditLogStore,
                    recordID: id,
                    isDraft: false
                )
            )
        case .quiz(let session):
            QuizView(
                session: session,
                path: $path,
                viewModel: QuizViewModel(session: session, brain: environment.brain)
            )
        case .narrate(let session):
            NarrateView(session: session, path: $path, transcriber: speechTranscriber)
        case .feedback(let session, let narrationText):
            FeedbackView(
                session: session,
                narrationText: narrationText,
                path: $path,
                viewModel: FeedbackViewModel(
                    session: session,
                    narrationText: narrationText,
                    brain: environment.brain
                )
            )
        }
    }
}
