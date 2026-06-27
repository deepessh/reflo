import SwiftUI

struct QuizView: View {
    let session: ChapterSession
    @Binding var path: NavigationPath
    @StateObject private var viewModel: QuizViewModel

    init(session: ChapterSession, path: Binding<NavigationPath>, viewModel: QuizViewModel) {
        self.session = session
        _path = path
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView("Preparing quiz…")
            case .failed(let message):
                ContentUnavailableView {
                    Label("Quiz Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            case .question:
                if let question = viewModel.currentQuestion {
                    questionView(question)
                }
            case .missed:
                if let question = viewModel.currentQuestion {
                    missedView(question)
                }
            case .finished:
                VStack(spacing: 16) {
                    Text("Quiz complete")
                        .font(.title2)
                    Text("Next, narrate what you learned from this chapter.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Continue to Narrate") {
                        path.append(AppRoute.narrate(session))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle(session.chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadQuiz()
        }
    }

    @ViewBuilder
    private func questionView(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(.title3)

                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        Task { await viewModel.selectChoice(at: index) }
                    } label: {
                        Text(choice)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func missedView(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question.prompt)
                    .font(.headline)

                if viewModel.isFetchingMending {
                    ProgressView("Loading explanation…")
                } else {
                    Text(viewModel.mendingParagraph)
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("From the book:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(question.bookExample)
                        .font(.body)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                if viewModel.showSecondExample {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Another example:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.secondExample)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Button(viewModel.isFetchingExample ? "Loading…" : "Show me another example") {
                        Task { await viewModel.fetchSecondExample() }
                    }
                    .disabled(viewModel.isFetchingExample)
                }

                Button("Continue") {
                    Task { await viewModel.continueAfterMiss() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
