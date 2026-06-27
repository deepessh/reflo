import SwiftUI

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

    init(session: ChapterSession, brain: any BrainServices) {
        self.session = session
        self.brain = brain
    }

    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    func loadQuiz() async {
        phase = .loading
        do {
            questions = try await brain.makeQuiz(chapterText: session.chapterText)
            currentIndex = 0
            phase = questions.isEmpty ? .failed("No questions available.") : .question
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func selectChoice(at index: Int) async {
        guard let question = currentQuestion else { return }
        if index == question.correctIndex {
            phase = .question
            await advanceOrFinish()
        } else {
            isFetchingMending = true
            phase = .missed
            do {
                mendingParagraph = try await brain.mend(question: question)
            } catch {
                mendingParagraph = "Something went wrong loading the explanation."
            }
            isFetchingMending = false
        }
    }

    func fetchSecondExample() async {
        guard let question = currentQuestion else { return }
        isFetchingExample = true
        do {
            secondExample = try await brain.secondExample(for: question)
            showSecondExample = true
        } catch {
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
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            phase = .question
        } else {
            phase = .finished
        }
    }
}
