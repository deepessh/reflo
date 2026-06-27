import SwiftUI

struct NarrateView: View {
    let session: ChapterSession
    @Binding var path: NavigationPath
    @StateObject private var viewModel: NarrateViewModel

    init(session: ChapterSession, path: Binding<NavigationPath>, transcriber: SpeechTranscriber) {
        self.session = session
        _path = path
        _viewModel = StateObject(wrappedValue: NarrateViewModel(
            session: session,
            transcriber: transcriber
        ))
    }

    var body: some View {
        Group {
            switch viewModel.permissionState {
            case .idle, .loading:
                ProgressView("Preparing microphone…")
            case .failed(let message):
                unavailableView(message: message)
            case .loaded:
                narrationContent
            }
        }
        .navigationTitle("Narrate")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.prepare()
        }
        .onReceive(viewModel.transcriber.objectWillChange) { _ in
            viewModel.updateLiveTranscript()
        }
    }

    @ViewBuilder
    private var narrationContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Explain what you learned from \"\(session.chapterTitle)\" out loud.")
                .font(.body)

            if let message = viewModel.transcriber.permissionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.transcript.isEmpty ? "Your words will appear here…" : viewModel.transcript)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(viewModel.transcript.isEmpty ? .tertiary : .primary)

            Button {
                viewModel.toggleRecording()
            } label: {
                Label(
                    viewModel.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(viewModel.isRecording ? "Stop recording" : "Start recording")

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button("Continue") {
                let text = viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                path.append(AppRoute.feedback(session, narrationText: text))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canContinue)
        }
        .padding()
    }

    @ViewBuilder
    private func unavailableView(message: String) -> some View {
        ContentUnavailableView {
            Label("Narration Unavailable", systemImage: "mic.slash")
        } description: {
            Text(message)
        } actions: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
            }
        }
    }
}
