import Foundation

struct LLMConfiguration: Sendable, Equatable {
    let endpoint: LLMEndpoint
    let apiKey: String?
    let model: String
    let temperature: Double
    let maxTokens: Int
    let useJSONResponseFormat: Bool
    let numQuestions: Int

    var baseURL: URL { endpoint.url }

    init(
        endpoint: LLMEndpoint,
        apiKey: String?,
        model: String,
        temperature: Double = 0.7,
        maxTokens: Int = 8192,
        useJSONResponseFormat: Bool = false,
        numQuestions: Int = 5
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.useJSONResponseFormat = useJSONResponseFormat
        self.numQuestions = numQuestions
    }

    static func make(
        baseURLString: String,
        apiKey: String?,
        model: String,
        httpConfirmed: Bool = false
    ) throws -> LLMConfiguration {
        let endpoint = try LLMEndpoint.parse(baseURLString, httpConfirmed: httpConfirmed)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw LLMSettingsError.invalidModel
        }
        return LLMConfiguration(endpoint: endpoint, apiKey: apiKey, model: trimmedModel)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
