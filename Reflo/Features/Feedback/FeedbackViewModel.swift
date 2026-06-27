import SwiftUI

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
        loadState = .loading
        do {
            let reply = try await brain.reply(narration: narrationText, chapterText: session.chapterText)
            loadState = .loaded(reply)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
