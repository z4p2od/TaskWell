import SwiftUI

/// Optional BYOK enrichment settings. Keys go to Keychain; toggles to UserDefaults.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var aiEnabled = EnrichmentSettings.aiEnrichmentEnabled
    @State private var provider = EnrichmentSettings.preferredProvider
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var statusMessage: String?
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use AI to enrich new tasks", isOn: $aiEnabled)
                        .onChange(of: aiEnabled) { _, value in
                            EnrichmentSettings.aiEnrichmentEnabled = value
                        }

                    Picker("Provider", selection: $provider) {
                        ForEach(EnrichmentSettings.Provider.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .onChange(of: provider) { _, value in
                        EnrichmentSettings.preferredProvider = value
                    }
                } header: {
                    Text("Enrichment")
                } footer: {
                    Text("When on and a key is saved, TaskWell may propose effort, duration, and enjoyment from a short title. You always confirm chips before saving. Off or no key = fully on-device.")
                }

                Section("OpenAI") {
                    keyField(
                        title: "API key",
                        text: $openAIKey,
                        revealed: $showOpenAIKey,
                        placeholder: "sk-…"
                    )
                    Button("Save OpenAI key") {
                        saveKey(openAIKey, service: .openAI, label: "OpenAI")
                    }
                    .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if KeychainStore.load(service: .openAI) != nil {
                        Button("Remove OpenAI key", role: .destructive) {
                            KeychainStore.delete(service: .openAI)
                            openAIKey = ""
                            statusMessage = "Removed OpenAI key."
                        }
                    }
                }

                Section("Anthropic") {
                    keyField(
                        title: "API key",
                        text: $anthropicKey,
                        revealed: $showAnthropicKey,
                        placeholder: "sk-ant-…"
                    )
                    Button("Save Anthropic key") {
                        saveKey(anthropicKey, service: .anthropic, label: "Anthropic")
                    }
                    .disabled(anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if KeychainStore.load(service: .anthropic) != nil {
                        Button("Remove Anthropic key", role: .destructive) {
                            KeychainStore.delete(service: .anthropic)
                            anthropicKey = ""
                            statusMessage = "Removed Anthropic key."
                        }
                    }
                    Text("Anthropic calls are stubbed for now — OpenAI is the live BYOK path. Saving a key keeps it ready.")
                        .font(.caption)
                        .foregroundStyle(TaskWellTheme.muted)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(TaskWellTheme.wellDeep)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Don’t load secrets into state by default — only show that a key exists via Remove.
                openAIKey = ""
                anthropicKey = ""
            }
        }
    }

    private func keyField(
        title: String,
        text: Binding<String>,
        revealed: Binding<Bool>,
        placeholder: String
    ) -> some View {
        HStack {
            Group {
                if revealed.wrappedValue {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            Button {
                revealed.wrappedValue.toggle()
            } label: {
                Image(systemName: revealed.wrappedValue ? "eye.slash" : "eye")
            }
            .accessibilityLabel(revealed.wrappedValue ? "Hide key" : "Show key")
        }
    }

    private func saveKey(_ raw: String, service: KeychainStore.Service, label: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainStore.save(trimmed, service: service)
            statusMessage = "Saved \(label) key in Keychain."
            if service == .openAI { openAIKey = "" }
            if service == .anthropic { anthropicKey = "" }
        } catch {
            statusMessage = "Couldn’t save \(label) key. Try again."
        }
    }
}
