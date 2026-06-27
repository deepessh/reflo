import SwiftUI

private let logger = AppLog.quiz

@MainActor
final class QuizViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case question
        case missed
        case finished
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var mendingParagraph = ""
    @Published private(set) var secondExample = ""
    @Published private(set) var showSecondExample = false
    @Published private(set) var isFetchingMending = false
    @Published private(set) var isFetchingExample = false

    let session: ChapterSession
    private let brain: any BrainServices
    private var selectedIndex: Int?

    init(session: ChapterSession, brain: any BrainServices) {
        self.session = session
        self.brain = brain
    }

    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    func loadQuiz() async {
        logger.debug("loadQuiz chapter='\(self.session.chapterTitle, privacy: .public)'")
        phase = .loading
        do {
            questions = try await brain.makeQuiz(
                bookTitle: session.bookTitle,
                chapterText: session.chapterText
            )
            currentIndex = 0
            phase = questions.isEmpty ? .failed("No questions available.") : .question
            logger.debug("loadQuiz loaded \(self.questions.count, privacy: .public) questions")
        } catch {
            logger.error("loadQuiz failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed(error.localizedDescription)
        }
    }

    func selectChoice(at index: Int) async {
        guard let question = currentQuestion else { return }
        let correct = index == question.correctIndex
        logger.debug("selectChoice q\(self.currentIndex, privacy: .public) index=\(index, privacy: .public) correct=\(correct, privacy: .public)")
        if correct {
            phase = .question
            await advanceOrFinish()
        } else {
            selectedIndex = index
            isFetchingMending = true
            phase = .missed
            do {
                mendingParagraph = try await brain.mend(question: question)
            } catch {
                logger.error("mend failed: \(error.localizedDescription, privacy: .public)")
                mendingParagraph = "Something went wrong loading the explanation."
            }
            isFetchingMending = false
        }
    }

    func fetchSecondExample() async {
        guard let question = currentQuestion, let pickedIndex = selectedIndex else { return }
        isFetchingExample = true
        do {
            secondExample = try await brain.secondExample(for: question, pickedChoiceIndex: pickedIndex)
            showSecondExample = true
        } catch {
            logger.error("secondExample failed: \(error.localizedDescription, privacy: .public)")
            secondExample = "Couldn't load another example."
            showSecondExample = true
        }
        isFetchingExample = false
    }

    func continueAfterMiss() async {
        await advanceOrFinish()
    }

    private func advanceOrFinish() async {
        showSecondExample = false
        secondExample = ""
        mendingParagraph = ""
        selectedIndex = nil
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            phase = .question
        } else {
            phase = .finished
        }
    }
}
