import Foundation

enum LLMModelSelectionMode: Equatable, Sendable {
    case fetched
    case custom
}

@MainActor
final class LLMSettingsViewModel: ObservableObject {
    @Published var endpointDraft = ""
    @Published var apiKeyDraft = ""
    @Published var modelDraft = ""
    @Published var customModelDraft = ""
    @Published var selectionMode: LLMModelSelectionMode = .custom
    @Published var fetchedModels: [String] = []
    @Published var httpConfirmed = false
    @Published var isLoading = true
    @Published var isFetchingModels = false
    @Published var isSaving = false
    @Published var isClearing = false
    @Published var loadError: String?
    @Published var fetchError: String?
    @Published var saveError: String?
    @Published var clearError: String?
    @Published var showClearConfirmation = false

    private let repository: LLMSettingsRepository
    private let catalogClient: ModelCatalogClient
    private var fetchGeneration = 0
    private var activeFetchTask: Task<Void, Never>?
    private var hasLoadedInitialState = false

    init(repository: LLMSettingsRepository, catalogClient: ModelCatalogClient) {
        self.repository = repository
        self.catalogClient = catalogClient
    }

    var requiresHTTPConfirmation: Bool {
        let trimmed = endpointDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        do {
            _ = try LLMEndpoint.parse(trimmed, httpConfirmed: false)
            return false
        } catch LLMEndpointError.httpConfirmationRequired {
            return true
        } catch {
            return false
        }
    }

    var canFetchModels: Bool {
        !endpointDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isFetchingModels
            && !isSaving
            && !isClearing
            && !isLoading
    }

    var canSave: Bool {
        !isSaving && !isClearing && !isLoading && !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedModel: String {
        switch selectionMode {
        case .fetched:
            return modelDraft
        case .custom:
            return customModelDraft
        }
    }

    func onAppear() async {
        guard !hasLoadedInitialState else { return }
        isLoading = true
        loadError = nil
        do {
            try await repository.bootstrap()
            if let snapshot = await repository.currentSnapshot() {
                endpointDraft = snapshot.endpointString
                apiKeyDraft = snapshot.apiKey ?? ""
                customModelDraft = snapshot.model
                modelDraft = snapshot.model
                selectionMode = .custom
                httpConfirmed = snapshot.confirmedHTTPEndpoint != nil
            }
            hasLoadedInitialState = true
        } catch let error as LLMSettingsError {
            loadError = error.errorDescription
        } catch {
            loadError = "Couldn't load AI settings."
        }
        isLoading = false
    }

    func onDisappear() {
        activeFetchTask?.cancel()
        activeFetchTask = nil
    }

    func endpointChanged() {
        cancelFetch()
        fetchedModels = []
        fetchError = nil
        httpConfirmed = false
    }

    func apiKeyChanged() {
        cancelFetch()
        fetchedModels = []
        fetchError = nil
    }

    func fetchModels() {
        guard canFetchModels else { return }
        if requiresHTTPConfirmation, !httpConfirmed {
            fetchError = LLMSettingsError.httpConfirmationRequired.errorDescription
            return
        }

        cancelFetch()
        fetchGeneration += 1
        let generation = fetchGeneration
        fetchError = nil
        isFetchingModels = true

        activeFetchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == self.fetchGeneration {
                    self.isFetchingModels = false
                }
            }

            do {
                let endpoint = try LLMEndpoint.parse(self.endpointDraft, httpConfirmed: self.httpConfirmed)
                let models = try await self.catalogClient.fetchModels(
                    endpoint: endpoint,
                    apiKey: self.apiKeyDraft.nilIfEmpty
                )
                guard !Task.isCancelled, generation == self.fetchGeneration else { return }
                self.fetchedModels = models
                if self.selectionMode == .fetched || models.contains(self.modelDraft) {
                    self.selectionMode = .fetched
                    if models.contains(self.modelDraft) {
                        // keep current selection
                    } else if let first = models.first {
                        self.modelDraft = first
                    }
                }
            } catch let error as LLMSettingsError {
                guard !Task.isCancelled, generation == self.fetchGeneration else { return }
                self.fetchError = error.errorDescription
            } catch {
                guard !Task.isCancelled, generation == self.fetchGeneration else { return }
                self.fetchError = LLMSettingsError.fetchNetwork.errorDescription
            }
        }
    }

    func save() async -> Bool {
        guard canSave else { return false }
        if requiresHTTPConfirmation, !httpConfirmed {
            saveError = LLMSettingsError.httpConfirmationRequired.errorDescription
            return false
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            _ = try await repository.save(
                LLMSettingsDraft(
                    endpointString: endpointDraft,
                    apiKey: apiKeyDraft,
                    model: selectedModel,
                    httpConfirmed: httpConfirmed
                )
            )
            return true
        } catch let error as LLMSettingsError {
            saveError = error.errorDescription
            return false
        } catch {
            saveError = LLMSettingsError.saveFailed.errorDescription
            return false
        }
    }

    func clearConfirmed() async {
        isClearing = true
        clearError = nil
        defer { isClearing = false }

        do {
            try await repository.clear()
            endpointDraft = ""
            apiKeyDraft = ""
            modelDraft = ""
            customModelDraft = ""
            selectionMode = .custom
            fetchedModels = []
            httpConfirmed = false
            fetchError = nil
            saveError = nil
        } catch let error as LLMSettingsError {
            clearError = error.errorDescription
        } catch {
            clearError = LLMSettingsError.clearFailed.errorDescription
        }
    }

    private func cancelFetch() {
        activeFetchTask?.cancel()
        activeFetchTask = nil
        isFetchingModels = false
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
