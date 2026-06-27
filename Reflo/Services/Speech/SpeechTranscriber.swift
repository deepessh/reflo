import AVFoundation
import Foundation
import Speech

private let logger = AppLog.speech

enum SpeechTranscriberError: Error, LocalizedError {
    case microphoneDenied
    case speechDenied
    case unavailable
    case notRecording

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is required to record your summary."
        case .speechDenied:
            return "Speech recognition access is required to transcribe your summary."
        case .unavailable:
            return "Speech recognition requires a device."
        case .notRecording:
            return "Not currently recording."
        }
    }
}

@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published private(set) var partialText = ""
    @Published private(set) var isRecording = false
    @Published private(set) var permissionMessage: String?

    private let worker = AudioCaptureWorker()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var committedText = ""

    init() {
        speechRecognizer = SFSpeechRecognizer()
        speechRecognizer?.defaultTaskHint = .dictation
    }

    var isAvailable: Bool {
        guard let speechRecognizer else { return false }
        return speechRecognizer.isAvailable
    }

    func requestPermissions() async throws {
        permissionMessage = "Reflo listens so you can explain what you learned out loud. Audio stays on your phone."

        let micGranted = await AVAudioApplication.requestRecordPermission()
        logger.debug("Microphone permission granted=\(micGranted, privacy: .public)")
        guard micGranted else { throw SpeechTranscriberError.microphoneDenied }

        let speechStatus = await Self.requestSpeechAuthorization()
        logger.debug("Speech authorization status=\(speechStatus.rawValue, privacy: .public)")
        guard speechStatus == .authorized else { throw SpeechTranscriberError.speechDenied }
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func start() throws {
        guard isAvailable else {
            logger.error("start() called while recognizer unavailable.")
            throw SpeechTranscriberError.unavailable
        }
        guard !isRecording else {
            logger.debug("start() ignored; already recording.")
            return
        }

        committedText = ""
        partialText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        worker.onBuffer = { buffer in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.handleRecognitionResult(result)
                }
                if let error {
                    logger.error("Recognition error: \(error.localizedDescription, privacy: .public)")
                    self.stopInternal()
                }
            }
        }

        try worker.start()
        isRecording = true
        logger.debug("Recording started.")
    }

    func stop() -> String {
        let result = partialText
        stopInternal()
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Recording stopped; transcript \(trimmed.count, privacy: .public) chars.")
        return trimmed
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        // `formattedString` is the cumulative hypothesis for the *current*
        // utterance, and iOS revises it (reorders, shortens, recapitalizes) as
        // more audio arrives. So we only ever show committed utterances plus the
        // current live one — never derive structure from length/prefix diffs.
        let utterance = result.bestTranscription.formattedString
        partialText = joinedTranscript(committedText, utterance)

        // `speechRecognitionMetadata` is non-nil only when iOS finalizes an
        // utterance after a natural pause; it then restarts transcription fresh
        // for the next utterance. Commit so the next one appends rather than
        // overwrites. `isFinal` covers the trailing utterance at stop().
        if result.speechRecognitionMetadata != nil || result.isFinal {
            committedText = joinedTranscript(committedText, utterance)
        }
    }

    private func joinedTranscript(_ committed: String, _ live: String) -> String {
        let committedTrimmed = committed.trimmingCharacters(in: .whitespacesAndNewlines)
        let liveTrimmed = live.trimmingCharacters(in: .whitespacesAndNewlines)
        if committedTrimmed.isEmpty { return liveTrimmed }
        if liveTrimmed.isEmpty { return committedTrimmed }
        return committedTrimmed + " " + liveTrimmed
    }

    private func stopInternal() {
        worker.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
