import SwiftUI

struct ChaptersView: View {
    let bookID: String
    @Binding var path: NavigationPath
    @StateObject private var viewModel: ChaptersViewModel

    init(bookID: String, path: Binding<NavigationPath>, viewModel: ChaptersViewModel) {
        self.bookID = bookID
        _path = path
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Loading chapters…")
            case .loaded(let chapters):
                if chapters.isEmpty {
                    ContentUnavailableView(
                        "No Chapters Found",
                        systemImage: "list.bullet",
                        description: Text("This book doesn't have a readable table of contents.")
                    )
                } else {
                    List(chapters) { chapter in
                        ChapterRow(
                            chapter: chapter,
                            isLoading: viewModel.rowStates[chapter.id]?.isLoading ?? false,
                            errorMessage: viewModel.rowErrors[chapter.id],
                            draftCount: viewModel.chapterDrafts[chapter.id]?.count ?? 0,
                            attemptCount: viewModel.chapterAttempts[chapter.id]?.count ?? 0,
                            canResume: viewModel.latestDraft(for: chapter.id) != nil,
                            onStartNew: {
                                await startNewQuiz(for: chapter)
                            },
                            onResume: {
                                resumeQuiz(for: chapter)
                            }
                        )
                    }
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Open Book", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
        .navigationTitle(viewModel.bookTitle.isEmpty ? "Chapters" : viewModel.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onAppear {
            Task { await viewModel.refreshQuizHistory() }
        }
    }

    private func startNewQuiz(for chapter: Chapter) async {
        if let launch = await viewModel.startNewQuiz(for: chapter) {
            path.append(AppRoute.quizFlow(launch))
        }
    }

    private func resumeQuiz(for chapter: Chapter) {
        if let launch = viewModel.resumeLatest(for: chapter) {
            path.append(AppRoute.quizFlow(launch))
        }
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isLoading: Bool
    let errorMessage: String?
    let draftCount: Int
    let attemptCount: Int
    let canResume: Bool
    let onStartNew: () async -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chapter.title)
                .font(.body)
                .padding(.leading, CGFloat(chapter.depth) * 16)

            HStack {
                Button(isLoading ? "Loading…" : "Start New") {
                    Task { await onStartNew() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if canResume {
                    Button("Resume") {
                        onResume()
                    }
                    .buttonStyle(.bordered)
                }

                if isLoading {
                    ProgressView()
                }
            }

            if draftCount > 0 || attemptCount > 0 {
                Text("\(draftCount) draft(s), \(attemptCount) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
