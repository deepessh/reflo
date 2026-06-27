import SwiftUI

private let logger = AppLog.narrate

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
        logger.debug("prepare available=\(self.transcriber.isAvailable, privacy: .public)")
        guard transcriber.isAvailable else {
            permissionState = .failed("Speech recognition requires a device.")
            return
        }
        permissionState = .loading
        do {
            try await transcriber.requestPermissions()
            permissionState = .loaded(true)
        } catch {
            logger.error("prepare permissions failed: \(error.localizedDescription, privacy: .public)")
            permissionState = .failed(error.localizedDescription)
        }
    }

    func toggleRecording() {
        errorMessage = nil
        if transcriber.isRecording {
            transcript = transcriber.stop()
            logger.debug("toggleRecording stopped; transcript \(self.transcript.count, privacy: .public) chars")
        } else {
            do {
                try transcriber.start()
                logger.debug("toggleRecording started")
            } catch {
                logger.error("toggleRecording start failed: \(error.localizedDescription, privacy: .public)")
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
