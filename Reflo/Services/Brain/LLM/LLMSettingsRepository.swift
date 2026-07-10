import Foundation

struct LLMSettingsSnapshot: Sendable, Equatable {
    let configuration: LLMConfiguration
    let confirmedHTTPEndpoint: String?

    var endpointString: String {
        configuration.endpoint.normalizedString
    }

    var model: String {
        configuration.model
    }

    var apiKey: String? {
        configuration.apiKey
    }
}

struct LLMSettingsDraft: Sendable, Equatable {
    let endpointString: String
    let apiKey: String
    let model: String
    let httpConfirmed: Bool
}

actor LLMSettingsRepository {
    static let currentSchemaVersion = 1
    static let metadataKey = "llmSettingsMetadata"
    static let firstLaunchKey = "llmSettingsFirstLaunchCompleted"

    private let defaults: UserDefaults
    private let keychain: KeychainSecretStore
    private var snapshot: LLMSettingsSnapshot?

    init(defaultsSuiteName: String? = nil, keychain: KeychainSecretStore = KeychainSecretStore()) {
        if let defaultsSuiteName {
            defaults = UserDefaults(suiteName: defaultsSuiteName)!
        } else {
            defaults = .standard
        }
        self.keychain = keychain
    }

    func bootstrap() throws {
        if defaults.object(forKey: Self.firstLaunchKey) == nil {
            for account in keychain.listAccounts() {
                try? keychain.delete(account: account)
            }
            defaults.set(true, forKey: Self.firstLaunchKey)
        }
        snapshot = try loadSnapshot()
    }

    func currentSnapshot() -> LLMSettingsSnapshot? {
        snapshot
    }

    func save(_ draft: LLMSettingsDraft) throws -> LLMSettingsSnapshot {
        let configuration = try LLMConfiguration.make(
            baseURLString: draft.endpointString,
            apiKey: draft.apiKey.nilIfEmpty,
            model: draft.model,
            httpConfirmed: draft.httpConfirmed
        )

        let endpointString = configuration.endpoint.normalizedString
        let confirmedHTTP = configuration.endpoint.requiresHTTPConfirmation ? endpointString : nil
        let secretID = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : UUID().uuidString

        if let secretID, let key = draft.apiKey.nilIfEmpty {
            do {
                try keychain.save(secret: key, account: secretID)
            } catch let error as KeychainSecretError {
                throw mapKeychainError(error)
            }
        }

        let metadata = PersistedMetadata(
            schemaVersion: Self.currentSchemaVersion,
            endpoint: endpointString,
            model: configuration.model,
            secretID: secretID,
            confirmedHTTPEndpoint: confirmedHTTP
        )

        do {
            let data = try JSONEncoder().encode(metadata)
            defaults.set(data, forKey: Self.metadataKey)
        } catch {
            throw LLMSettingsError.saveFailed
        }

        let newSnapshot = LLMSettingsSnapshot(
            configuration: configuration,
            confirmedHTTPEndpoint: confirmedHTTP
        )
        snapshot = newSnapshot
        cleanupOrphanSecrets(referencedID: secretID)
        return newSnapshot
    }

    func clear() throws {
        defaults.removeObject(forKey: Self.metadataKey)
        snapshot = nil
    }

    private func loadSnapshot() throws -> LLMSettingsSnapshot? {
        guard let data = defaults.data(forKey: Self.metadataKey) else {
            return nil
        }

        let metadata: PersistedMetadata
        do {
            metadata = try JSONDecoder().decode(PersistedMetadata.self, from: data)
        } catch {
            throw LLMSettingsError.persistenceCorrupt
        }

        guard metadata.schemaVersion == Self.currentSchemaVersion else {
            throw LLMSettingsError.persistenceUnsupportedSchema(version: metadata.schemaVersion)
        }

        let httpConfirmed = metadata.confirmedHTTPEndpoint != nil
        let endpoint: LLMEndpoint
        do {
            endpoint = try LLMEndpoint.parse(metadata.endpoint, httpConfirmed: httpConfirmed)
        } catch let error as LLMEndpointError {
            throw LLMSettingsError.invalidEndpoint(error)
        }

        if endpoint.requiresHTTPConfirmation {
            guard metadata.confirmedHTTPEndpoint == endpoint.normalizedString else {
                throw LLMSettingsError.persistenceCorrupt
            }
        } else if metadata.confirmedHTTPEndpoint != nil {
            throw LLMSettingsError.persistenceCorrupt
        }

        let trimmedModel = metadata.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw LLMSettingsError.persistenceCorrupt
        }

        var apiKey: String?
        if let secretID = metadata.secretID {
            do {
                apiKey = try keychain.load(account: secretID)
            } catch KeychainSecretError.notFound {
                throw LLMSettingsError.persistenceCorrupt
            } catch let error as KeychainSecretError {
                throw mapKeychainError(error)
            }
        }

        cleanupOrphanSecrets(referencedID: metadata.secretID)

        return LLMSettingsSnapshot(
            configuration: LLMConfiguration(
                endpoint: endpoint,
                apiKey: apiKey,
                model: trimmedModel
            ),
            confirmedHTTPEndpoint: metadata.confirmedHTTPEndpoint
        )
    }

    private func cleanupOrphanSecrets(referencedID: String?) {
        for account in keychain.listAccounts() where account != referencedID {
            try? keychain.delete(account: account)
        }
    }

    private func mapKeychainError(_ error: KeychainSecretError) -> LLMSettingsError {
        switch error {
        case .protectedDataUnavailable:
            return .keychainProtected
        case .notFound:
            return .persistenceCorrupt
        case .unexpectedStatus:
            return .keychainFailure
        }
    }
}

private struct PersistedMetadata: Codable, Sendable {
    let schemaVersion: Int
    let endpoint: String
    let model: String
    let secretID: String?
    let confirmedHTTPEndpoint: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
