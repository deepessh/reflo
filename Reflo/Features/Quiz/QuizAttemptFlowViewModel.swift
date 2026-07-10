import Foundation

enum QuizLaunch: Hashable, Sendable {
    case new(id: UUID, session: ChapterSession)
    case resume(draftID: UUID)
}

enum QuizAttemptPhase: Equatable {
    case loading
    case generating
    case savingDraft
    case question
    case missed
    case narrating
    case feedback
    case failed(String)
}

@MainActor
final class QuizAttemptFlowViewModel: ObservableObject {
    @Published private(set) var phase: QuizAttemptPhase = .loading
    @Published private(set) var draft: QuizDraft?
    @Published private(set) var completedAttempt: CompletedQuizAttempt?
    @Published private(set) var mendingParagraph = ""
    @Published private(set) var secondExample = ""
    @Published private(set) var showSecondExample = false
    @Published private(set) var isFetchingMending = false
    @Published private(set) var isFetchingExample = false
    @Published private(set) var isSavingTranscript = false
    @Published private(set) var transcriptSaveError: String?
    @Published private(set) var feedbackReply = ""
    @Published private(set) var isFetchingReply = false
    @Published private(set) var replyFailed = false

    let launch: QuizLaunch
    private let brain: any BrainServices
    private let lifecycle: QuizDraftLifecycle
    private let transcriber: SpeechTranscriber
    private var inFlightRequestID: UUID?
    private var generatedQuestions: [QuizQuestion]?

    init(
        launch: QuizLaunch,
        brain: any BrainServices,
        lifecycle: QuizDraftLifecycle,
        transcriber: SpeechTranscriber
    ) {
        self.launch = launch
        self.brain = brain
        self.lifecycle = lifecycle
        self.transcriber = transcriber
    }

    var session: ChapterSession? {
        switch launch {
        case .new(_, let session):
            return session
        case .resume:
            return draft.map {
                ChapterSession(
                    bookID: $0.chapter.bookID,
                    bookTitle: $0.chapter.bookTitle,
                    chapterID: $0.chapter.chapterID,
                    chapterTitle: $0.chapter.chapterTitle,
                    chapterText: $0.chapter.chapterText
                )
            }
        }
    }

    var currentQuestion: CapturedQuestionState? {
        guard let draft, let index = draft.stage.questionIndex else { return nil }
        guard draft.questions.indices.contains(index) else { return nil }
        return draft.questions[index]
    }

    var currentQuestionIndex: Int {
        draft?.stage.questionIndex ?? 0
    }

    var questionCount: Int {
        draft?.questions.count ?? 0
    }

    var narrationTranscript: String {
        draft?.narrationTranscript ?? ""
    }

    func bootstrap() async {
        phase = .loading
        do {
            switch launch {
            case .new(let id, let session):
                try await startNewQuiz(id: id, session: session)
            case .resume(let draftID):
                try await resumeDraft(id: draftID)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func selectChoice(at index: Int) async {
        guard let draft else { return }
        guard let questionIndex = draft.stage.questionIndex else { return }
        isFetchingMending = true
        do {
            let result = try await lifecycle.selectChoice(
                draft: draft,
                questionIndex: questionIndex,
                selectedIndex: index
            )
            self.draft = result.draft
            switch result.effect {
            case .fetchMending(let qIndex, let requestID):
                inFlightRequestID = requestID
                phase = .missed
                await fetchMending(questionIndex: qIndex)
            case .publish:
                isFetchingMending = false
                updatePhaseFromDraft()
            default:
                isFetchingMending = false
                updatePhaseFromDraft()
            }
        } catch {
            isFetchingMending = false
            phase = .failed(error.localizedDescription)
        }
    }

    func fetchSecondExample() async {
        guard let draft, let questionIndex = draft.stage.questionIndex else { return }
        isFetchingExample = true
        do {
            let result = try await lifecycle.requestSecondExample(draft: draft, questionIndex: questionIndex)
            self.draft = result.draft
            if case .fetchSecondExample(let qIndex, let requestID) = result.effect {
                inFlightRequestID = requestID
                await loadSecondExample(questionIndex: qIndex)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        isFetchingExample = false
    }

    func continueAfterMiss() async {
        guard let draft, let questionIndex = draft.stage.questionIndex else { return }
        do {
            let result = try await lifecycle.continueFromMending(draft: draft, questionIndex: questionIndex)
            self.draft = result.draft
            resetMissUI()
            updatePhaseFromDraft()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stopRecordingAndSave() async {
        guard let draft else { return }
        let text = transcriber.stop()
        isSavingTranscript = true
        transcriptSaveError = nil
        do {
            let result = try await lifecycle.updateNarrationTranscript(draft: draft, text: text)
            self.draft = result.draft
        } catch {
            transcriptSaveError = error.localizedDescription
        }
        isSavingTranscript = false
    }

    func submitNarration() async {
        guard let draft else { return }
        let text = draft.narrationTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isFetchingReply = true
        replyFailed = false
        do {
            let result = try await lifecycle.submitNarration(draft: draft, transcript: text)
            self.draft = result.draft
            if case .fetchReply(let requestID) = result.effect {
                inFlightRequestID = requestID
                await fetchReply()
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        isFetchingReply = false
    }

    func retryReply() async {
        guard let draft else { return }
        isFetchingReply = true
        do {
            let result = try await lifecycle.retryReply(draft: draft)
            self.draft = result.draft
            if case .fetchReply(let requestID) = result.effect {
                inFlightRequestID = requestID
                await fetchReply()
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        isFetchingReply = false
    }

    private func startNewQuiz(id: UUID, session: ChapterSession) async throws {
        phase = .generating
        let questions: [QuizQuestion]
        if let generatedQuestions {
            questions = generatedQuestions
        } else {
            questions = try await brain.makeQuiz(bookTitle: session.bookTitle, chapterText: session.chapterText)
            generatedQuestions = questions
        }

        phase = .savingDraft
        do {
            let created = try await lifecycle.createDraft(id: id, session: session, questions: questions)
            draft = created
            phase = .question
        } catch {
            phase = .savingDraft
            throw error
        }
    }

    private func resumeDraft(id: UUID) async throws {
        guard let loaded = try await lifecycle.loadDraft(id: id) else {
            throw QuizAuditStoreError.draftNotFound(id)
        }
        draft = loaded
        await resumeSideEffects()
        updatePhaseFromDraft()
    }

    private func resumeSideEffects() async {
        guard let draft else { return }
        switch QuizDraftLifecycle.permittedEffect(for: draft) {
        case .fetchMending(let questionIndex, let requestID):
            inFlightRequestID = requestID
            phase = .missed
            await fetchMending(questionIndex: questionIndex)
        case .fetchSecondExample(let questionIndex, let requestID):
            inFlightRequestID = requestID
            await loadSecondExample(questionIndex: questionIndex)
        case .fetchReply(let requestID):
            inFlightRequestID = requestID
            await fetchReply()
        case .finalize:
            await finalizeIfNeeded()
        case .none, .publish:
            break
        }
    }

    private func fetchMending(questionIndex: Int) async {
        guard let draft, let question = draft.questions[questionIndex].question.asQuizQuestion else { return }
        let pickedIndex = draft.questions[questionIndex].answer?.selectedIndex ?? 0
        isFetchingMending = true
        do {
            let text = try await brain.mend(
                question: question,
                pickedChoiceIndex: pickedIndex,
                bookTitle: draft.chapter.bookTitle,
                chapterTitle: draft.chapter.chapterTitle
            )
            let result = try await lifecycle.recordMending(
                draft: self.draft!,
                questionIndex: questionIndex,
                text: text,
                failed: false
            )
            self.draft = result.draft
            mendingParagraph = text
        } catch {
            let fallback = "Something went wrong loading the explanation."
            if let currentDraft = self.draft {
                let result = try? await lifecycle.recordMending(
                    draft: currentDraft,
                    questionIndex: questionIndex,
                    text: fallback,
                    failed: true
                )
                self.draft = result?.draft ?? currentDraft
            }
            mendingParagraph = fallback
        }
        if let example = self.draft?.questions[questionIndex].secondExampleText {
            secondExample = example
            showSecondExample = true
        }
        isFetchingMending = false
    }

    private func loadSecondExample(questionIndex: Int) async {
        guard let draft, let question = draft.questions[questionIndex].question.asQuizQuestion else { return }
        let pickedIndex = draft.questions[questionIndex].answer?.selectedIndex ?? 0
        isFetchingExample = true
        do {
            let text = try await brain.secondExample(for: question, pickedChoiceIndex: pickedIndex)
            let result = try await lifecycle.recordSecondExample(
                draft: draft,
                questionIndex: questionIndex,
                text: text,
                failed: false
            )
            self.draft = result.draft
            secondExample = text
            showSecondExample = true
        } catch {
            let fallback = "Couldn't load another example."
            let result = try? await lifecycle.recordSecondExample(
                draft: draft,
                questionIndex: questionIndex,
                text: fallback,
                failed: true
            )
            self.draft = result?.draft ?? draft
            secondExample = fallback
            showSecondExample = true
        }
        isFetchingExample = false
    }

    private func fetchReply() async {
        guard let draft else { return }
        isFetchingReply = true
        do {
            let reply = try await brain.reply(
                narration: draft.narrationTranscript,
                chapterText: draft.chapter.chapterText
            )
            let outcome = try await lifecycle.recordReplySuccess(draft: draft, replyText: reply.text)
            self.draft = outcome.draft
            completedAttempt = outcome.attempt
            feedbackReply = reply.text
            replyFailed = false
            phase = .feedback
        } catch {
            let result = try? await lifecycle.recordReplyFailure(draft: draft)
            self.draft = result?.draft ?? draft
            replyFailed = true
            phase = .feedback
        }
        isFetchingReply = false
    }

    private func finalizeIfNeeded() async {
        guard let draft else { return }
        do {
            completedAttempt = try await lifecycle.resumeFinalization(draft: draft)
            feedbackReply = completedAttempt?.narrationReply ?? ""
            phase = .feedback
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func updatePhaseFromDraft() {
        guard let draft else {
            phase = .failed("Draft missing.")
            return
        }
        switch draft.stage {
        case .answering:
            phase = .question
        case .mendingPending, .mendingReview, .secondExamplePending:
            phase = .missed
            if let index = draft.stage.questionIndex {
                mendingParagraph = draft.questions[index].mendingText ?? mendingParagraph
                if let example = draft.questions[index].secondExampleText {
                    secondExample = example
                    showSecondExample = true
                }
            }
        case .narrating, .replyPending, .replyFailed:
            phase = .narrating
            replyFailed = draft.stage == .replyFailed
        case .finalizationPending:
            phase = .feedback
            Task { await finalizeIfNeeded() }
        }
    }

    private func resetMissUI() {
        showSecondExample = false
        secondExample = ""
        mendingParagraph = ""
        isFetchingMending = false
        isFetchingExample = false
    }
}

private extension CapturedQuizQuestion {
    var asQuizQuestion: QuizQuestion? {
        QuizQuestion(
            id: id,
            prompt: prompt,
            options: options.map {
                QuizQuestionOption(text: $0.text, isCorrect: $0.isCorrect, trapType: $0.trapType)
            },
            bookExample: bookExample,
            idea: idea
        )
    }
}
