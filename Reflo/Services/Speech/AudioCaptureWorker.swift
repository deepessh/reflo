import AVFoundation
import Foundation

private let logger = AppLog.speech

final class AudioCaptureWorker: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var isRunning = false

    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
        logger.debug("Audio engine started; format \(format.sampleRate, privacy: .public)Hz \(format.channelCount, privacy: .public)ch")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.debug("Audio engine stopped.")
    }
}
