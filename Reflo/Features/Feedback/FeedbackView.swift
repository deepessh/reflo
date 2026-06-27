import SwiftUI

struct FeedbackView: View {
    let session: ChapterSession
    let narrationText: String
    @Binding var path: NavigationPath
    @StateObject private var viewModel: FeedbackViewModel

    init(
        session: ChapterSession,
        narrationText: String,
        path: Binding<NavigationPath>,
        viewModel: FeedbackViewModel
    ) {
        self.session = session
        self.narrationText = narrationText
        _path = path
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Reflecting on what you said…")
            case .loaded(let reply):
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(reply.text)
                            .font(.body)

                        Button("Done") {
                            path = NavigationPath([AppRoute.chapters(bookID: session.bookID)])
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Feedback Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Back to Chapters") {
                        path = NavigationPath([AppRoute.chapters(bookID: session.bookID)])
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadReply()
        }
    }
}
