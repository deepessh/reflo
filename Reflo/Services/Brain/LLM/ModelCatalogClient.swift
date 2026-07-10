import Foundation
import os

private let logger = AppLog.llm

struct ModelCatalogClient: Sendable {
    private let transport: any HTTPTransport

    init(transport: any HTTPTransport) {
        self.transport = transport
    }

    func fetchModels(endpoint: LLMEndpoint, apiKey: String?) async throws -> [String] {
        let url = endpoint.routeURL(for: .models)
        var headers: [String: String] = [:]
        if let apiKey, !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        logger.debug("GET models route modelDiscovery=1")

        let started = Date()
        let response: HTTPResponse
        do {
            response = try await transport.send(
                HTTPRequest(url: url, method: "GET", headers: headers)
            )
        } catch HTTPTransportError.cancelled {
            throw LLMSettingsError.fetchCancelled
        } catch {
            throw LLMSettingsError.fetchNetwork
        }

        let elapsedMS = Date().timeIntervalSince(started) * 1000
        logger.debug("models HTTP \(response.statusCode, privacy: .public) in \(elapsedMS, format: .fixed(precision: 0), privacy: .public)ms, \(response.body.count, privacy: .public) bytes")

        switch response.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw LLMSettingsError.fetchUnauthorized
        case 403:
            throw LLMSettingsError.fetchForbidden
        case 404, 405:
            throw LLMSettingsError.fetchUnsupported
        default:
            throw LLMSettingsError.fetchNetwork
        }

        let models: [String]
        do {
            models = try Self.decodeModelIDs(from: response.body)
        } catch {
            throw LLMSettingsError.fetchDecoding
        }

        guard !models.isEmpty else {
            throw LLMSettingsError.fetchEmptyCatalog
        }

        return models
    }

    static func decodeModelIDs(from data: Data) throws -> [String] {
        let payload = try JSONDecoder().decode(ModelsListResponse.self, from: data)
        var seen = Set<String>()
        var ids: [String] = []
        for entry in payload.data {
            let trimmed = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                ids.append(trimmed)
            }
        }
        return ids.sorted()
    }
}

private struct ModelsListResponse: Decodable {
    let data: [ModelEntry]
}

private struct ModelEntry: Decodable {
    let id: String
}
