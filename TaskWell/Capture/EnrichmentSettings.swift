import Foundation

/// User preferences for optional cloud enrichment (toggle only — keys live in Keychain).
enum EnrichmentSettings {
    private static let aiEnabledKey = "taskwell.enrichment.aiEnabled"
    private static let providerKey = "taskwell.enrichment.provider"

    enum Provider: String, CaseIterable, Identifiable {
        case openAI
        case anthropic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .openAI: "OpenAI"
            case .anthropic: "Anthropic"
            }
        }

        var keychainService: KeychainStore.Service {
            switch self {
            case .openAI: .openAI
            case .anthropic: .anthropic
            }
        }
    }

    static var aiEnrichmentEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: aiEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: aiEnabledKey) }
    }

    static var preferredProvider: Provider {
        get {
            let raw = UserDefaults.standard.string(forKey: providerKey) ?? Provider.openAI.rawValue
            return Provider(rawValue: raw) ?? .openAI
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static func apiKey(for provider: Provider) -> String? {
        KeychainStore.load(service: provider.keychainService)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static var canUseAI: Bool {
        aiEnrichmentEnabled && apiKey(for: preferredProvider) != nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
