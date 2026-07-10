import Foundation
import os

private let logger = AppLog.llm

struct OpenAICompatibleClient: LanguageModelClient {
    private let endpoint: LLMEndpoint
    private let apiKey: String?
    private let transport: any HTTPTransport

    init(configuration: LLMConfiguration, transport: any HTTPTransport) {
        self.endpoint = configuration.endpoint
        self.apiKey = configuration.apiKey
        self.transport = transport
    }

    func complete(_ request: CompletionRequest) async throws -> CompletionResponse {
        let url = endpoint.routeURL(for: .chatCompletions)
        var headers = [
            "Content-Type": "application/json"
        ]
        if let apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        logger.debug("POST chat/completions model=\(request.model, privacy: .public) messages=\(request.messages.count, privacy: .public) maxTokens=\(request.maxTokens, privacy: .public)")

        let started = Date()
        let response: HTTPResponse
        do {
            response = try await transport.send(
                HTTPRequest(
                    url: url,
                    method: "POST",
                    headers: headers,
                    body: try JSONEncoder().encode(makeBody(for: request))
                )
            )
        } catch {
            throw LanguageModelError.network(message: "Network request failed.")
        }

        let elapsedMS = Date().timeIntervalSince(started) * 1000
        logger.debug("chat/completions HTTP \(response.statusCode, privacy: .public) in \(elapsedMS, format: .fixed(precision: 0), privacy: .public)ms, \(response.body.count, privacy: .public) bytes")

        guard (200 ... 299).contains(response.statusCode) else {
            logger.error("chat/completions HTTP \(response.statusCode, privacy: .public)")
            throw LanguageModelError.http(status: response.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: response.body)
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
