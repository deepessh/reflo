import SwiftUI

struct QuizAttemptFlowView: View {
    @Binding var path: NavigationPath
    @StateObject private var viewModel: QuizAttemptFlowViewModel
    @Environment(\.speechTranscriber) private var transcriber

    init(path: Binding<NavigationPath>, viewModel: QuizAttemptFlowViewModel) {
        _path = path
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading, .generating, .savingDraft:
                ProgressView(progressLabel)
            case .failed(let message):
                ContentUnavailableView("Quiz Unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
            case .question:
                if let question = viewModel.currentQuestion {
                    questionView(question)
                }
            case .missed:
                if let question = viewModel.currentQuestion {
                    missedView(question)
                }
            case .narrating:
                narrateView
            case .feedback:
                feedbackView
            }
        }
        .navigationTitle(viewModel.session?.chapterTitle ?? "Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.bootstrap() }
    }

    private var progressLabel: String {
        switch viewModel.phase {
        case .generating: return "Preparing quiz…"
        case .savingDraft: return "Saving quiz…"
        default: return "Loading…"
        }
    }

    @ViewBuilder
    private func questionView(_ question: CapturedQuestionState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(question.question.prompt)
                    .font(.title3)
                ForEach(Array(question.question.options.enumerated()), id: \.offset) { index, choice in
                    Button {
                        Task { await viewModel.selectChoice(at: index) }
                    } label: {
                        Text(choice.text)
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
    private func missedView(_ question: CapturedQuestionState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question.question.prompt)
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
                    Text(question.question.bookExample)
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

    private var narrateView: some View {
        VStack(spacing: 16) {
            Text("Narrate what you learned")
                .font(.title3)
            Text(viewModel.narrationTranscript.isEmpty ? "Tap the microphone and explain the chapter in your own words." : viewModel.narrationTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button(transcriber.isRecording ? "Stop" : "Record") {
                    Task {
                        if transcriber.isRecording {
                            await viewModel.stopRecordingAndSave()
                        } else {
                            try? transcriber.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if viewModel.isSavingTranscript {
                    ProgressView()
                }
            }

            if let error = viewModel.transcriptSaveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Continue to Feedback") {
                Task { await viewModel.submitNarration() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.narrationTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isFetchingReply)
        }
        .padding()
    }

    private var feedbackView: some View {
        VStack(spacing: 16) {
            if viewModel.isFetchingReply {
                ProgressView("Loading feedback…")
            } else if viewModel.replyFailed {
                Text("Couldn't load feedback.")
                Button("Try Again") {
                    Task { await viewModel.retryReply() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(viewModel.feedbackReply)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Done") {
                if let session = viewModel.session {
                    path = NavigationPath([AppRoute.chapters(bookID: session.bookID)])
                } else {
                    path = NavigationPath()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
