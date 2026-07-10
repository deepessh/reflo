import SwiftUI

struct QuizzesView: View {
    @Binding var path: NavigationPath
    @StateObject private var viewModel: QuizzesViewModel

    init(path: Binding<NavigationPath>, viewModel: QuizzesViewModel) {
        _path = path
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading quizzes…")
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Quizzes Yet",
                    systemImage: "questionmark.circle",
                    description: Text("Start a quiz from any chapter to create a draft or completed attempt.")
                )
            } else {
                List(viewModel.items) { item in
                    switch item {
                    case .draft(let summary):
                        Button {
                            path.append(AppRoute.quizFlow(.resume(draftID: summary.id)))
                        } label: {
                            draftRow(summary)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Discard", role: .destructive) {
                                viewModel.requestDiscard(draftID: summary.id)
                            }
                        }
                    case .attempt(let summary):
                        NavigationLink(value: AppRoute.attemptDetail(id: summary.id)) {
                            attemptRow(summary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quizzes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog(
            "Discard this unfinished quiz?",
            isPresented: Binding(
                get: { viewModel.pendingDiscardID != nil },
                set: { if !$0 { viewModel.cancelDiscard() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Draft", role: .destructive) {
                Task { await viewModel.confirmDiscard() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDiscard()
            }
        }
        .alert("Couldn't Discard", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func draftRow(_ summary: QuizDraftSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.chapterTitle)
                .font(.headline)
            Text(summary.bookTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Draft · \(stageLabel(summary.stage))")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func attemptRow(_ summary: CompletedAttemptSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.chapterTitle)
                .font(.headline)
            Text(summary.bookTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Completed · \(summary.completedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stageLabel(_ stage: QuizDraftStage) -> String {
        switch stage {
        case .answering(let index):
            return "Question \(index + 1)"
        case .mendingPending, .mendingReview, .secondExamplePending:
            return "Reviewing miss"
        case .narrating:
            return "Narrating"
        case .replyPending, .replyFailed:
            return "Awaiting feedback"
        case .finalizationPending:
            return "Finalizing"
        }
    }
}

struct AttemptDetailView: View {
    @StateObject private var viewModel: AttemptDetailViewModel

    init(viewModel: AttemptDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Loading attempt…")
            case .failed(let message):
                ContentUnavailableView("Couldn't Load", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded:
                if let attempt = viewModel.attempt {
                    attemptContent(attempt)
                } else if let draft = viewModel.draft {
                    draftContent(draft)
                }
            }
        }
        .navigationTitle("Quiz Record")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func attemptContent(_ attempt: CompletedQuizAttempt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(bookTitle: attempt.chapter.bookTitle, chapterTitle: attempt.chapter.chapterTitle, completedAt: attempt.completedAt)
                ForEach(Array(attempt.questions.enumerated()), id: \.element.id) { index, question in
                    questionBlock(question, index: index)
                }
                narrationBlock(transcript: attempt.narrationTranscript, reply: attempt.narrationReply)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func draftContent(_ draft: QuizDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(bookTitle: draft.chapter.bookTitle, chapterTitle: draft.chapter.chapterTitle, completedAt: draft.updatedAt)
                Text("Unfinished draft")
                    .font(.caption)
                    .foregroundStyle(.orange)
                ForEach(Array(draft.questions.enumerated()), id: \.element.id) { index, question in
                    questionBlock(question, index: index)
                }
                if !draft.narrationTranscript.isEmpty {
                    narrationBlock(transcript: draft.narrationTranscript, reply: draft.narrationReply)
                }
            }
            .padding()
        }
    }

    private func header(bookTitle: String, chapterTitle: String, completedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chapterTitle).font(.title2)
            Text(bookTitle).foregroundStyle(.secondary)
            Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func questionBlock(_ question: CapturedQuestionState, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question.question.prompt)
                .font(.headline)
            ForEach(Array(question.question.options.enumerated()), id: \.offset) { optionIndex, option in
                HStack(alignment: .top) {
                    Text(option.text)
                    Spacer()
                    if option.isCorrect {
                        Text("correct").font(.caption2).foregroundStyle(.green)
                    } else if let trap = option.trapType {
                        Text(trap.rawValue).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(
                    question.answer?.selectedIndex == optionIndex
                        ? Color.accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            if let mending = question.mendingText {
                Text(mending).font(.body)
            }
            if let example = question.secondExampleText {
                Text(example).font(.body)
            }
        }
    }

    private func narrationBlock(transcript: String, reply: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Narration").font(.headline)
            Text(transcript)
            if let reply {
                Text("Reply").font(.headline)
                Text(reply)
            }
        }
    }
}
