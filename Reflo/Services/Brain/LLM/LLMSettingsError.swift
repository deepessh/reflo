import Foundation

enum LLMSettingsError: Error, Equatable, Sendable {
    case notConfigured
    case invalidEndpoint(LLMEndpointError)
    case invalidModel
    case missingEndpoint
    case missingModel
    case httpConfirmationRequired
    case persistenceCorrupt
    case persistenceUnsupportedSchema(version: Int)
    case keychainProtected
    case keychainFailure
    case saveFailed
    case clearFailed
    case fetchCancelled
    case fetchUnauthorized
    case fetchForbidden
    case fetchUnsupported
    case fetchEmptyCatalog
    case fetchNetwork
    case fetchDecoding

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI is not configured. Open Settings to add your endpoint and model."
        case .invalidEndpoint(let underlying):
            return underlying.userMessage
        case .invalidModel, .missingModel:
            return "Enter a model name."
        case .missingEndpoint:
            return "Enter an API base URL."
        case .httpConfirmationRequired:
            return "Confirm that you want to use plain HTTP for this private endpoint."
        case .persistenceCorrupt:
            return "Saved AI settings look invalid. Clear configuration and set them up again."
        case .persistenceUnsupportedSchema(let version):
            return "Saved AI settings use an unsupported version (\(version)). Clear configuration and set them up again."
        case .keychainProtected:
            return "Unlock your device and try again."
        case .keychainFailure:
            return "Couldn't access secure storage for the API key."
        case .saveFailed:
            return "Couldn't save AI settings."
        case .clearFailed:
            return "Couldn't clear AI settings."
        case .fetchCancelled:
            return "Model fetch was cancelled."
        case .fetchUnauthorized:
            return "The server rejected the API key (401)."
        case .fetchForbidden:
            return "The server denied access to the models list (403)."
        case .fetchUnsupported:
            return "This endpoint doesn't expose a compatible models list."
        case .fetchEmptyCatalog:
            return "The server returned no models."
        case .fetchNetwork:
            return "Couldn't reach the AI service."
        case .fetchDecoding:
            return "Couldn't read the models list from the server."
        }
    }
}

private extension LLMEndpointError {
    var userMessage: String {
        switch self {
        case .emptyInput:
            return "Enter an API base URL."
        case .invalidURL, .invalidHost:
            return "Enter a valid API base URL with a host."
        case .unsupportedComponent(let name):
            return "The API base URL can't include \(name)."
        case .publicHTTPNotAllowed:
            return "Plain HTTP is only allowed for localhost and private-network endpoints."
        case .httpConfirmationRequired:
            return "Confirm that you want to use plain HTTP for this private endpoint."
        }
    }
}
