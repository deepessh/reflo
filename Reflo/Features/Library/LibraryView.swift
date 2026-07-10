import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    @StateObject private var viewModel: LibraryViewModel
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    init(viewModel: LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Loading library…")
            case .loaded(let books) where books.isEmpty:
                ContentUnavailableView {
                    Label("No Books Yet", systemImage: "books.vertical")
                } description: {
                    Text("Add an EPUB to start quizzing yourself chapter by chapter.")
                } actions: {
                    addButton
                }
            case .loaded:
                List(viewModel.books) { book in
                    NavigationLink(value: AppRoute.chapters(bookID: book.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayTitle(for: book))
                                .font(.headline)
                            Text(book.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.loadBooks() }
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    NavigationLink(value: AppRoute.quizzes) {
                        Label("Quizzes", systemImage: "questionmark.circle")
                    }
                    addButton
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            LLMSettingsView(
                viewModel: LLMSettingsViewModel(
                    repository: appEnvironment.llmSettingsRepository,
                    catalogClient: appEnvironment.modelCatalogClient
                )
            )
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await viewModel.importBook(from: url) }
            case .failure:
                viewModel.importError = "Couldn't add this book."
            }
        }
        .alert("Import Failed", isPresented: Binding(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.importError ?? "")
        }
        .overlay {
            if viewModel.isImporting {
                ProgressView("Adding book…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await viewModel.loadBooks()
        }
    }

    private var addButton: some View {
        Button {
            isImporterPresented = true
        } label: {
            Label("Add Book", systemImage: "plus")
        }
        .disabled(viewModel.isImporting)
    }

    private func displayTitle(for book: Book) -> String {
        switch viewModel.titleLoadStates[book.id] {
        case .loaded(let title):
            return title
        default:
            return book.title
        }
    }
}
