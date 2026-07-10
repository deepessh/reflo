import XCTest
@testable import Reflo

final class QuizResponseParserTests: XCTestCase {
    func testParsesCleanJSON() throws {
        let questions = try QuizResponseParser.parseQuestions(from: Self.sampleJSON)
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions[0].prompt, "Which best explains the loop?")
        XCTAssertEqual(questions[0].choices.count, 4)
        XCTAssertTrue(questions[0].correctIndex >= 0 && questions[0].correctIndex < 4)
        XCTAssertEqual(questions[0].bookExample, "The highway widening example.")
    }

    func testParsesFencedJSON() throws {
        let wrapped = """
        Here is the quiz:
        ```json
        \(Self.sampleJSON)
        ```
        """
        let questions = try QuizResponseParser.parseQuestions(from: wrapped)
        XCTAssertEqual(questions.count, 1)
    }

    func testParsesJSONWithBracesInStrings() throws {
        let json = """
        {
          "questions": [
            {
              "book_example": "The author uses {braces} in the example.",
              "stem": "What is the main idea?",
              "options": [
                { "text": "Correct", "correct": true },
                { "text": "Wrong {not json}", "correct": false }
              ]
            }
          ]
        }
        """
        let questions = try QuizResponseParser.parseQuestions(from: json)
        XCTAssertEqual(questions[0].bookExample, "The author uses {braces} in the example.")
    }

    func testRejectsZeroCorrectOptions() {
        let json = """
        {
          "questions": [
            {
              "book_example": "Example",
              "stem": "Question?",
              "options": [
                { "text": "A", "correct": false },
                { "text": "B", "correct": false }
              ]
            }
          ]
        }
        """
        XCTAssertThrowsError(try QuizResponseParser.parseQuestions(from: json)) { error in
            XCTAssertTrue(error is LanguageModelError)
        }
    }

    func testRejectsMultipleCorrectOptions() {
        let json = """
        {
          "questions": [
            {
              "book_example": "Example",
              "stem": "Question?",
              "options": [
                { "text": "A", "correct": true },
                { "text": "B", "correct": true }
              ]
            }
          ]
        }
        """
        XCTAssertThrowsError(try QuizResponseParser.parseQuestions(from: json))
    }

    func testRejectsInvalidJSON() {
        XCTAssertThrowsError(try QuizResponseParser.parseQuestions(from: "{ not valid json"))
    }

    fileprivate static let sampleJSON = """
    {
      "core_ideas": [
        {
          "idea": "Feedback loops shape behavior.",
          "overturns": "Pushing harder on one lever always fixes the system."
        }
      ],
      "questions": [
        {
          "idea": "Feedback loops shape behavior.",
          "book_example": "The highway widening example.",
          "stem": "Which best explains the loop?",
          "options": [
            {
              "text": "More lanes change how people drive until congestion returns.",
              "correct": true,
              "misconception": null,
              "depth": null,
              "note": "Right on the merits."
            },
            {
              "text": "The widening simply was not big enough.",
              "correct": false,
              "misconception": "Push harder on the obvious lever.",
              "depth": "false_belief",
              "note": "Tempting but shallow."
            },
            {
              "text": "Population growth alone caused the traffic.",
              "correct": false,
              "misconception": "Single outside cause.",
              "depth": "flawed_model",
              "note": "Coherent but wrong model."
            },
            {
              "text": "Congestion is a fixed property of the road.",
              "correct": false,
              "misconception": "Relationship mistaken for a thing.",
              "depth": "wrong_category",
              "note": "Category error."
            }
          ]
        }
      ]
    }
    """
}

final class QuizPromptBuilderTests: XCTestCase {
    func testSubstitutesPlaceholders() {
        let builder = QuizPromptBuilder(template: """
        BOOK: {{BOOK_TITLE}}
        COUNT: {{NUM_QUESTIONS}}
        CHAPTER:
        {{CHAPTER_TEXT}}
        """)

        let messages = builder.messages(
            bookTitle: "Thinking in Systems",
            chapterText: "Chapter body here.",
            numQuestions: 5
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertTrue(messages[1].content.contains("BOOK: Thinking in Systems"))
        XCTAssertTrue(messages[1].content.contains("COUNT: 5"))
        XCTAssertTrue(messages[1].content.contains("Chapter body here."))
    }

    func testLoadsBundledPromptResource() throws {
        let promptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("prompts/questions.md")
        let template = try String(contentsOf: promptURL, encoding: .utf8)
        let builder = QuizPromptBuilder(template: template)
        let messages = builder.messages(
            bookTitle: "Sample Book",
            chapterText: "Sample chapter.",
            numQuestions: 3
        )
        XCTAssertTrue(messages[1].content.contains("Sample Book"))
        XCTAssertTrue(messages[1].content.contains("Sample chapter."))
        XCTAssertTrue(messages[1].content.contains("3"))
    }
}

final class ModelBrainServicesTests: XCTestCase {
    private static let sampleQuestion = QuizQuestion(
        id: "q1",
        prompt: "Which best explains the loop?",
        choices: [
            "More lanes change how people drive until congestion returns.",
            "The widening simply was not big enough.",
            "Population growth alone caused the traffic.",
            "Congestion is a fixed property of the road."
        ],
        correctIndex: 0,
        bookExample: "The highway widening example.",
        idea: "Feedback loops shape behavior."
    )

    private func makeConfig() -> LLMConfiguration {
        LLMConfiguration(
            baseURL: URL(string: "https://example.com/v1")!,
            apiKey: "test-key",
            model: "test-model",
            temperature: 0.7,
            maxTokens: 4096,
            useJSONResponseFormat: false,
            numQuestions: 1
        )
    }

    func testMakeQuizUsesClientAndMapsResponse() async throws {
        let config = makeConfig()

        var client = FakeLanguageModelClient(responses: [
            QuizResponseParserTests.sampleJSON
        ])

        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "BOOK: {{BOOK_TITLE}}\n{{CHAPTER_TEXT}}")
        )

        let questions = try await brain.makeQuiz(bookTitle: "Test Book", chapterText: "Chapter text.")
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(client.callCount, 1)
        XCTAssertEqual(client.lastRequest?.model, "test-model")
        XCTAssertTrue(client.lastRequest?.messages.last?.content.contains("Test Book") == true)
    }

    func testMakeQuizRetriesAfterParseFailure() async throws {
        let config = makeConfig()

        var client = FakeLanguageModelClient(responses: [
            "{ invalid",
            QuizResponseParserTests.sampleJSON
        ])

        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "{{BOOK_TITLE}} {{CHAPTER_TEXT}}")
        )

        let questions = try await brain.makeQuiz(bookTitle: "Retry Book", chapterText: "Chapter.")
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(client.callCount, 2)
    }

    func testMendThrowsAfterExhaustedRetries() async throws {
        let config = makeConfig()
        let client = FakeLanguageModelClient(responses: ["", ""])
        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "{{BOOK_TITLE}}")
        )

        do {
            _ = try await brain.mend(
                question: Self.sampleQuestion,
                pickedChoiceIndex: 1,
                bookTitle: "Test Book",
                chapterTitle: "Chapter 1"
            )
            XCTFail("Expected mend to throw after exhausted retries")
        } catch let error as LanguageModelError {
            guard case .emptyResponse = error else {
                XCTFail("Expected LanguageModelError.emptyResponse, got \(error)")
                return
            }
        }
        XCTAssertEqual(client.callCount, 2)
    }

    func testMendRetriesThenSucceeds() async throws {
        let config = makeConfig()
        let client = FakeLanguageModelClient(responses: ["", "Mended explanation text."])
        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "{{BOOK_TITLE}}")
        )

        let text = try await brain.mend(
            question: Self.sampleQuestion,
            pickedChoiceIndex: 1,
            bookTitle: "Test Book",
            chapterTitle: "Chapter 1"
        )
        XCTAssertEqual(text, "Mended explanation text.")
        XCTAssertEqual(client.callCount, 2)
    }

    func testReplyThrowsAfterExhaustedRetries() async throws {
        let config = makeConfig()
        let client = FakeLanguageModelClient(responses: ["", ""])
        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "{{BOOK_TITLE}}")
        )

        do {
            _ = try await brain.reply(narration: "I think the main idea is feedback.", chapterText: "Chapter body.")
            XCTFail("Expected reply to throw after exhausted retries")
        } catch let error as LanguageModelError {
            guard case .emptyResponse = error else {
                XCTFail("Expected LanguageModelError.emptyResponse, got \(error)")
                return
            }
        }
        XCTAssertEqual(client.callCount, 2)
    }

    func testReplyRetriesThenSucceeds() async throws {
        let config = makeConfig()
        let client = FakeLanguageModelClient(responses: ["", "A thoughtful reply."])
        let brain = ModelBrainServices(
            client: client,
            config: config,
            promptBuilder: QuizPromptBuilder(template: "{{BOOK_TITLE}}")
        )

        let reply = try await brain.reply(narration: "I think the main idea is feedback.", chapterText: "Chapter body.")
        XCTAssertEqual(reply.text, "A thoughtful reply.")
        XCTAssertEqual(client.callCount, 2)
    }
}

private final class FakeLanguageModelClient: LanguageModelClient, @unchecked Sendable {
    private var responses: [String]
    private(set) var callCount = 0
    private(set) var lastRequest: CompletionRequest?

    init(responses: [String]) {
        self.responses = responses
    }

    func complete(_ request: CompletionRequest) async throws -> CompletionResponse {
        callCount += 1
        lastRequest = request
        guard !responses.isEmpty else {
            throw LanguageModelError.emptyResponse
        }
        let next = responses.removeFirst()
        return CompletionResponse(text: next, finishReason: "stop")
    }
}
