import Foundation

struct LLMConfiguration: Sendable {
    let baseURL: URL
    let apiKey: String
    let model: String
    let temperature: Double
    let maxTokens: Int
    let useJSONResponseFormat: Bool
    let numQuestions: Int

    static let configFileName = "LLMConfig"

    static func load(from bundle: Bundle = .main) -> LLMConfiguration? {
        guard let url = bundle.url(forResource: configFileName, withExtension: "plist") else {
            return nil
        }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }

        guard let apiKey = plist["apiKey"] as? String,
              !apiKey.isEmpty,
              apiKey != "YOUR_SK_DO_MODEL_ACCESS_KEY",
              let model = plist["model"] as? String,
              !model.isEmpty
        else {
            return nil
        }

        let baseURLString = plist["baseURL"] as? String ?? "https://inference.do-ai.run/v1"
        guard let baseURL = URL(string: baseURLString) else {
            return nil
        }

        let temperature = plist["temperature"] as? Double ?? 0.7
        let maxTokens = plist["maxTokens"] as? Int ?? 8192
        let useJSONResponseFormat = plist["useJSONResponseFormat"] as? Bool ?? false
        let numQuestions = plist["numQuestions"] as? Int ?? 5

        return LLMConfiguration(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            useJSONResponseFormat: useJSONResponseFormat,
            numQuestions: numQuestions
        )
    }
}
