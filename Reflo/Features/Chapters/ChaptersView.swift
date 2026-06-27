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
                            errorMessage: viewModel.rowErrors[chapter.id]
                        ) {
                            await startQuiz(for: chapter)
                        }
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
    }

    private func startQuiz(for chapter: Chapter) async {
        if let session = await viewModel.startQuiz(for: chapter) {
            path.append(AppRoute.quiz(session))
        }
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isLoading: Bool
    let errorMessage: String?
    let onStartQuiz: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chapter.title)
                .font(.body)
                .padding(.leading, CGFloat(chapter.depth) * 16)

            HStack {
                Button(isLoading ? "Loading…" : "Start Quiz") {
                    Task { await onStartQuiz() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if isLoading {
                    ProgressView()
                }
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
