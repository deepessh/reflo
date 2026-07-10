import XCTest
@testable import Reflo

final class LLMEndpointTests: XCTestCase {
    func testParsesHTTPSWithPathPrefix() throws {
        let endpoint = try LLMEndpoint.parse("https://Host.Example/v1/")
        XCTAssertEqual(endpoint.normalizedString, "https://host.example/v1")
        XCTAssertEqual(
            endpoint.routeURL(for: .models).absoluteString,
            "https://host.example/v1/models"
        )
        XCTAssertEqual(
            endpoint.routeURL(for: .chatCompletions).absoluteString,
            "https://host.example/v1/chat/completions"
        )
    }

    func testRejectsPublicHTTP() {
        XCTAssertThrowsError(try LLMEndpoint.parse("http://example.com/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .publicHTTPNotAllowed)
        }
    }

    func testAllowsPrivateHTTPWithConfirmation() throws {
        let endpoint = try LLMEndpoint.parse("http://192.168.1.10:8080/v1", httpConfirmed: true)
        XCTAssertTrue(endpoint.requiresHTTPConfirmation)
        XCTAssertEqual(endpoint.normalizedString, "http://192.168.1.10:8080/v1")
    }

    func testRequiresHTTPConfirmationWhenNotConfirmed() {
        XCTAssertThrowsError(try LLMEndpoint.parse("http://127.0.0.1/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .httpConfirmationRequired)
        }
    }

    func testRejectsLegacyNumericHost() {
        XCTAssertThrowsError(try LLMEndpoint.parse("http://134744072/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .invalidHost)
        }
        XCTAssertThrowsError(try LLMEndpoint.parse("http://0134/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .invalidHost)
        }
        XCTAssertThrowsError(try LLMEndpoint.parse("http://0x7f000001/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .invalidHost)
        }
    }

    func testClassifiesIPv4MappedIPv6AsPublicWhenMappedToPublic() {
        XCTAssertThrowsError(try LLMEndpoint.parse("http://[::ffff:8.8.8.8]/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .publicHTTPNotAllowed)
        }
    }

    func testRejectsQueryAndUserinfo() {
        XCTAssertThrowsError(try LLMEndpoint.parse("https://user:pass@example.com/v1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .unsupportedComponent("userinfo"))
        }
        XCTAssertThrowsError(try LLMEndpoint.parse("https://example.com/v1?api-version=1")) { error in
            XCTAssertEqual(error as? LLMEndpointError, .unsupportedComponent("query"))
        }
    }
}

final class LLMSettingsRepositoryTests: XCTestCase {
    private func makeSuiteName() -> String {
        "LLMSettingsRepositoryTests.\(UUID().uuidString)"
    }

    func testSaveAndLoadRoundTripWithKey() async throws {
        let suiteName = makeSuiteName()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let keychain = KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        let repository = LLMSettingsRepository(defaultsSuiteName: suiteName, keychain: keychain)
        try await repository.bootstrap()

        let snapshot = try await repository.save(
            LLMSettingsDraft(
                endpointString: "https://example.com/v1",
                apiKey: "secret-key",
                model: "gpt-test",
                httpConfirmed: false
            )
        )

        XCTAssertEqual(snapshot.model, "gpt-test")
        XCTAssertEqual(snapshot.apiKey, "secret-key")

        let reloaded = LLMSettingsRepository(defaultsSuiteName: suiteName, keychain: keychain)
        try await reloaded.bootstrap()
        let loaded = await reloaded.currentSnapshot()
        XCTAssertEqual(loaded?.model, "gpt-test")
        XCTAssertEqual(loaded?.apiKey, "secret-key")
    }

    func testSaveWithoutKey() async throws {
        let suiteName = makeSuiteName()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let keychain = KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        let repository = LLMSettingsRepository(defaultsSuiteName: suiteName, keychain: keychain)
        try await repository.bootstrap()

        let snapshot = try await repository.save(
            LLMSettingsDraft(
                endpointString: "https://example.com/v1",
                apiKey: "",
                model: "local-model",
                httpConfirmed: false
            )
        )

        XCTAssertNil(snapshot.apiKey)
    }

    func testClearRemovesSnapshot() async throws {
        let suiteName = makeSuiteName()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let keychain = KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        let repository = LLMSettingsRepository(defaultsSuiteName: suiteName, keychain: keychain)
        try await repository.bootstrap()
        _ = try await repository.save(
            LLMSettingsDraft(
                endpointString: "https://example.com/v1",
                apiKey: "secret",
                model: "model",
                httpConfirmed: false
            )
        )

        try await repository.clear()
        let snapshot = await repository.currentSnapshot()
        XCTAssertNil(snapshot)
    }
}

final class ModelCatalogClientTests: XCTestCase {
    func testDecodesAndSortsUniqueModelIDs() throws {
        let json = """
        {"data":[{"id":" zephyr "},{"id":"alpha"},{"id":"alpha"},{"id":""}]}
        """
        let ids = try ModelCatalogClient.decodeModelIDs(from: Data(json.utf8))
        XCTAssertEqual(ids, ["alpha", "zephyr"])
    }

    func testFetchIncludesAuthorizationWhenKeyPresent() async throws {
        let endpoint = try LLMEndpoint.parse("https://example.com/v1")
        let json = #"{"data":[{"id":"one"}]}"#
        let transport = FakeHTTPTransport(responses: [
            (HTTPResponse(statusCode: 200, body: Data(json.utf8)), nil)
        ])
        let client = ModelCatalogClient(transport: transport)
        let models = try await client.fetchModels(endpoint: endpoint, apiKey: "abc")
        XCTAssertEqual(models, ["one"])

        let observations = await transport.observations
        XCTAssertEqual(observations.first?.request.headers["Authorization"], "Bearer abc")
    }

    func testFetchMaps401() async throws {
        let endpoint = try LLMEndpoint.parse("https://example.com/v1")
        let transport = FakeHTTPTransport(responses: [
            (HTTPResponse(statusCode: 401, body: Data()), nil)
        ])
        let client = ModelCatalogClient(transport: transport)

        do {
            _ = try await client.fetchModels(endpoint: endpoint, apiKey: nil)
            XCTFail("Expected unauthorized error")
        } catch let error as LLMSettingsError {
            XCTAssertEqual(error, .fetchUnauthorized)
        }
    }
}

final class ConfigurableBrainServicesTests: XCTestCase {
    func testThrowsNotConfiguredWhenEmpty() async {
        let suiteName = "ConfigurableBrainServicesTests.\(UUID().uuidString)"
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let repository = LLMSettingsRepository(
            defaultsSuiteName: suiteName,
            keychain: KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        )
        try? await repository.bootstrap()

        let brain = ConfigurableBrainServices(
            repository: repository,
            transport: FakeHTTPTransport(responses: []),
            quizPromptBuilderResult: .success(QuizPromptBuilder(template: "{{BOOK_TITLE}}"))
        )

        do {
            _ = try await brain.makeQuiz(bookTitle: "Book", chapterText: "Chapter")
            XCTFail("Expected not configured")
        } catch {
            guard let modelError = error as? LanguageModelError,
                  case .notConfigured = modelError
            else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testUsesSavedSnapshotPerOperation() async throws {
        let suiteName = "ConfigurableBrainServicesTests.\(UUID().uuidString)"
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let keychain = KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        let repository = LLMSettingsRepository(defaultsSuiteName: suiteName, keychain: keychain)
        try await repository.bootstrap()
        _ = try await repository.save(
            LLMSettingsDraft(
                endpointString: "https://example.com/v1",
                apiKey: "key",
                model: "configured-model",
                httpConfirmed: false
            )
        )

        let json = """
        {"questions":[{"book_example":"Example","stem":"Which best explains the loop?","options":[{"text":"Correct","correct":true},{"text":"Wrong","correct":false},{"text":"Wrong2","correct":false},{"text":"Wrong3","correct":false}]}]}
        """
        let transport = FakeHTTPTransport(responses: [
            (HTTPResponse(statusCode: 200, body: Self.chatCompletionBody(json)), nil)
        ])

        let brain = ConfigurableBrainServices(
            repository: repository,
            transport: transport,
            quizPromptBuilderResult: .success(QuizPromptBuilder(template: "{{BOOK_TITLE}} {{CHAPTER_TEXT}}"))
        )

        let questions = try await brain.makeQuiz(bookTitle: "Book", chapterText: "Chapter")
        XCTAssertEqual(questions.count, 1)

        let observations = await transport.observations
        XCTAssertTrue(observations.first?.request.url.path.hasSuffix("/chat/completions") == true)
    }

    private static func chatCompletionBody(_ text: String) -> Data {
        let payload = """
        {"choices":[{"message":{"content":\(String(reflecting: text))},"finish_reason":"stop"}]}
        """
        return Data(payload.utf8)
    }
}

final class OpenAICompatibleClientTests: XCTestCase {
    func testOmitsAuthorizationWithoutKey() async throws {
        let endpoint = try LLMEndpoint.parse("https://example.com/v1")
        let config = LLMConfiguration(endpoint: endpoint, apiKey: nil, model: "test")
        let transport = FakeHTTPTransport(responses: [
            (HTTPResponse(statusCode: 200, body: Self.successBody("Hello")), nil)
        ])
        let client = OpenAICompatibleClient(configuration: config, transport: transport)

        let response = try await client.complete(
            CompletionRequest(
                messages: [ChatMessage(role: .user, content: "Hi")],
                model: "test",
                temperature: 0.7,
                maxTokens: 10,
                responseFormat: .text
            )
        )
        XCTAssertEqual(response.text, "Hello")

        let observations = await transport.observations
        XCTAssertNil(observations.first?.request.headers["Authorization"])
    }

    private static func successBody(_ text: String) -> Data {
        let payload = """
        {"choices":[{"message":{"content":\(String(reflecting: text))},"finish_reason":"stop"}]}
        """
        return Data(payload.utf8)
    }
}

final class LLMSettingsViewModelTests: XCTestCase {
    @MainActor
    func testFetchRequiresHTTPConfirmation() async throws {
        let suiteName = "LLMSettingsViewModelTests.\(UUID().uuidString)"
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let repository = LLMSettingsRepository(
            defaultsSuiteName: suiteName,
            keychain: KeychainSecretStore(service: "com.reflo.tests.\(UUID().uuidString)")
        )
        let viewModel = LLMSettingsViewModel(
            repository: repository,
            catalogClient: ModelCatalogClient(transport: FakeHTTPTransport(responses: []))
        )

        await viewModel.onAppear()
        viewModel.endpointDraft = "http://127.0.0.1:1234/v1"
        viewModel.fetchModels()
        XCTAssertEqual(viewModel.fetchError, LLMSettingsError.httpConfirmationRequired.errorDescription)
    }
}
