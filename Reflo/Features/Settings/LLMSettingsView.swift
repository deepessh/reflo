import SwiftUI

struct LLMSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LLMSettingsViewModel

    init(viewModel: LLMSettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoading {
                    Section {
                        ProgressView("Loading settings…")
                    }
                }

                if let loadError = viewModel.loadError {
                    Section {
                        Text(loadError)
                            .foregroundStyle(.red)
                    }
                }

                Section("API Base URL") {
                    TextField("https://host.example/v1", text: $viewModel.endpointDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: viewModel.endpointDraft) { _, _ in
                            viewModel.endpointChanged()
                        }

                    if viewModel.requiresHTTPConfirmation {
                        Text("Plain HTTP is allowed only for localhost and private-network endpoints.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Toggle("I confirm this private HTTP endpoint", isOn: $viewModel.httpConfirmed)
                    }
                }

                Section("API Key (optional)") {
                    SecureField("Bearer token", text: $viewModel.apiKeyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.apiKeyDraft) { _, _ in
                            viewModel.apiKeyChanged()
                        }
                }

                Section("Model") {
                    Button {
                        viewModel.fetchModels()
                    } label: {
                        if viewModel.isFetchingModels {
                            HStack {
                                ProgressView()
                                Text("Fetching models…")
                            }
                        } else {
                            Label("Fetch Models", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(!viewModel.canFetchModels)

                    if let fetchError = viewModel.fetchError {
                        Text(fetchError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    if !viewModel.fetchedModels.isEmpty {
                        Picker("Fetched model", selection: $viewModel.selectionMode) {
                            Text("From list").tag(LLMModelSelectionMode.fetched)
                            Text("Custom…").tag(LLMModelSelectionMode.custom)
                        }
                        .pickerStyle(.segmented)

                        if viewModel.selectionMode == .fetched {
                            Picker("Model", selection: $viewModel.modelDraft) {
                                ForEach(viewModel.fetchedModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }
                    }

                    if viewModel.fetchedModels.isEmpty || viewModel.selectionMode == .custom {
                        TextField("Custom model name", text: $viewModel.customModelDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if let saveError = viewModel.saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                }

                if let clearError = viewModel.clearError {
                    Section {
                        Text(clearError)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Clear Configuration", role: .destructive) {
                        viewModel.showClearConfirmation = true
                    }
                    .disabled(viewModel.isSaving || viewModel.isClearing || viewModel.isLoading)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving || viewModel.isClearing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving || viewModel.isClearing)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving || viewModel.isClearing)
            .confirmationDialog(
                "Clear saved AI settings?",
                isPresented: $viewModel.showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Configuration", role: .destructive) {
                    Task { await viewModel.clearConfirmed() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
    }
}
