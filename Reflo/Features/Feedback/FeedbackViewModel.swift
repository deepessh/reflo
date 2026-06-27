import SwiftUI

private let logger = AppLog.feedback

@MainActor
final class FeedbackViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<NarrationReply> = .idle

    let session: ChapterSession
    let narrationText: String
    private let brain: any BrainServices

    init(session: ChapterSession, narrationText: String, brain: any BrainServices) {
        self.session = session
        self.narrationText = narrationText
        self.brain = brain
    }

    func loadReply() async {
        logger.debug("loadReply narration=\(self.narrationText.count, privacy: .public) chars")
        loadState = .loading
        do {
            let reply = try await brain.reply(narration: narrationText, chapterText: session.chapterText)
            loadState = .loaded(reply)
            logger.debug("loadReply success")
        } catch {
            logger.error("loadReply failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(error.localizedDescription)
        }
    }
}
