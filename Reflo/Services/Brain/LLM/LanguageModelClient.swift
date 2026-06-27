import Foundation

enum ChatRole: String, Sendable, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Sendable, Equatable {
    let role: ChatRole
    let content: String
}

enum ResponseFormat: Sendable, Equatable {
    case text
    case jsonObject
}

struct CompletionRequest: Sendable {
    let messages: [ChatMessage]
    let model: String
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat
}

struct CompletionResponse: Sendable {
    let text: String
    let finishReason: String?
}

enum LanguageModelError: Error, LocalizedError, Sendable {
    case notConfigured
    case http(status: Int)
    case network(message: String)
    case emptyResponse
    case decoding(message: String)
    case truncated
    case contextWindowExceeded

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI is not configured. Copy LLMConfig.example.plist to LLMConfig.plist and add your key."
        case .http(let status):
            return "The AI service returned an error (HTTP \(status))."
        case .network(let message):
            return "Couldn't reach the AI service: \(message)"
        case .emptyResponse:
            return "The AI service returned an empty response."
        case .decoding(let message):
            return "Couldn't read the quiz from the AI response: \(message)"
        case .truncated:
            return "The AI response was cut off. Try again or use a shorter chapter."
        case .contextWindowExceeded:
            return "This chapter is too long for the AI model's context window."
        }
    }
}

protocol LanguageModelClient: Sendable {
    func complete(_ request: CompletionRequest) async throws -> CompletionResponse
}
