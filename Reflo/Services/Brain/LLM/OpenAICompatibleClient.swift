import Foundation
import os

private let logger = AppLog.llm

struct OpenAICompatibleClient: LanguageModelClient {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(configuration: LLMConfiguration, session: URLSession? = nil) {
        self.baseURL = configuration.baseURL
        self.apiKey = configuration.apiKey

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 150
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
    }

    func complete(_ request: CompletionRequest) async throws -> CompletionResponse {
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(makeBody(for: request))

        logger.debug("POST \(url.absoluteString, privacy: .public) model=\(request.model, privacy: .public) messages=\(request.messages.count, privacy: .public) maxTokens=\(request.maxTokens, privacy: .public)")

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            throw LanguageModelError.network(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            logger.error("Invalid response type (not HTTPURLResponse).")
            throw LanguageModelError.network(message: "Invalid response type.")
        }

        let elapsedMS = Date().timeIntervalSince(started) * 1000
        logger.debug("HTTP \(http.statusCode, privacy: .public) in \(elapsedMS, format: .fixed(precision: 0), privacy: .public)ms, \(data.count, privacy: .public) bytes")

        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("HTTP \(http.statusCode): \(body, privacy: .private)")
            throw LanguageModelError.http(status: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let choice = decoded.choices.first else {
            logger.error("Decoded response had no choices.")
            throw LanguageModelError.emptyResponse
        }

        let text = choice.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            logger.error("Choice content was empty.")
            throw LanguageModelError.emptyResponse
        }

        logger.debug("Completion ok: \(text.count, privacy: .public) chars, finishReason=\(choice.finishReason ?? "nil", privacy: .public)")
        return CompletionResponse(text: text, finishReason: choice.finishReason)
    }

    private func makeBody(for request: CompletionRequest) -> ChatCompletionRequestBody {
        var body = ChatCompletionRequestBody(
            model: request.model,
            messages: request.messages.map { ChatCompletionMessage(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        if request.responseFormat == .jsonObject {
            body.responseFormat = ResponseFormatPayload(type: "json_object")
        }

        return body
    }
}

private struct ChatCompletionRequestBody: Encodable {
    let model: String
    let messages: [ChatCompletionMessage]
    let temperature: Double
    let maxTokens: Int
    var responseFormat: ResponseFormatPayload?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

private struct ResponseFormatPayload: Encodable {
    let type: String
}

private struct ChatCompletionMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [ChatCompletionChoice]
}

private struct ChatCompletionChoice: Decodable {
    let message: ChatCompletionResponseMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

private struct ChatCompletionResponseMessage: Decodable {
    let content: String?
}
