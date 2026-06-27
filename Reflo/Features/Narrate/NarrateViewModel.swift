import SwiftUI

@MainActor
final class NarrateViewModel: ObservableObject {
    @Published private(set) var permissionState: LoadState<Bool> = .idle
    @Published private(set) var transcript = ""
    @Published var errorMessage: String?

    let session: ChapterSession
    let transcriber: SpeechTranscriber

    init(session: ChapterSession, transcriber: SpeechTranscriber) {
        self.session = session
        self.transcriber = transcriber
    }

    var canContinue: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isRecording: Bool {
        transcriber.isRecording
    }

    var partialText: String {
        transcriber.partialText
    }

    var isAvailable: Bool {
        transcriber.isAvailable
    }

    func prepare() async {
        guard transcriber.isAvailable else {
            permissionState = .failed("Speech recognition requires a device.")
            return
        }
        permissionState = .loading
        do {
            try await transcriber.requestPermissions()
            permissionState = .loaded(true)
        } catch {
            permissionState = .failed(error.localizedDescription)
        }
    }

    func toggleRecording() {
        errorMessage = nil
        if transcriber.isRecording {
            transcript = transcriber.stop()
        } else {
            do {
                try transcriber.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateLiveTranscript() {
        if transcriber.isRecording {
            transcript = transcriber.partialText
        }
    }
}
