import Foundation

/// Enrich a parsed draft (especially title-only) with effort / duration / enjoyment proposals.
/// Local by default; optional BYOK providers fill remaining gaps. Never auto-saves.
protocol TaskEnriching {
    func enrich(
        _ draft: ParsedTaskDraft,
        completed: [PoolTask]
    ) async -> ParsedTaskDraft
}

/// On-device heuristics + similar Done actuals. Always available, free.
struct LocalTaskEnricher: TaskEnriching {
    private let similarity: any CompletionDefaultsSuggesting

    init(similarity: any CompletionDefaultsSuggesting = SimilarTaskDefaultsSuggester()) {
        self.similarity = similarity
    }

    func enrich(
        _ draft: ParsedTaskDraft,
        completed: [PoolTask]
    ) async -> ParsedTaskDraft {
        var next = draft
        applyTitleHeuristics(to: &next)

        let suggestion = similarity.suggestDefaults(forTitle: next.title, from: completed)
        if next.durationMinutes == nil, let minutes = suggestion.durationMinutes {
            next.durationMinutes = minutes
            next.durationSource = .similar
        }
        if next.effort == nil, let effort = suggestion.effort {
            next.effort = effort
            next.effortSource = .similar
        }
        if next.enjoyment == nil, let enjoyment = suggestion.enjoyment {
            next.enjoyment = enjoyment
            next.enjoymentSource = .similar
        }
        return next
    }

    private func applyTitleHeuristics(to draft: inout ParsedTaskDraft) {
        let title = draft.title.lowercased()
        guard !title.isEmpty else { return }

        func setDuration(_ minutes: Int) {
            guard draft.durationMinutes == nil else { return }
            draft.durationMinutes = minutes
            draft.durationSource = .enriched
        }
        func setEffort(_ effort: EffortLevel) {
            guard draft.effort == nil else { return }
            draft.effort = effort
            draft.effortSource = .enriched
        }
        func setEnjoyment(_ enjoyment: EnjoymentLevel) {
            guard draft.enjoyment == nil else { return }
            draft.enjoyment = enjoyment
            draft.enjoymentSource = .enriched
        }

        if title.contains(anyOf: ["buy", "shop", "grocer", "errand", "store"]) {
            setEffort(.medium)
            setDuration(25)
        }
        if title.contains(anyOf: ["email", "reply", "text", "message", "call", "ping"]) {
            setEffort(.quick)
            setDuration(10)
        }
        if title.contains(anyOf: ["write", "draft", "outline", "blog", "report"]) {
            setEffort(.medium)
            setDuration(35)
        }
        if title.contains(anyOf: ["clean", "laundry", "dishes", "kitchen", "vacuum"]) {
            setEffort(.medium)
            setDuration(20)
            setEnjoyment(.meh)
        }
        if title.contains(anyOf: ["tax", "receipt", "invoice", "budget", "file ", "filing"]) {
            setEffort(.big)
            setDuration(45)
            setEnjoyment(.dread)
        }
        if title.contains(anyOf: ["walk", "run", "exercise", "gym", "yoga"]) {
            setEffort(.quick)
            setDuration(30)
            setEnjoyment(.enjoy)
        }
        if title.contains(anyOf: ["read", "chapter", "book", "novel"]) {
            setEffort(.medium)
            setDuration(30)
            setEnjoyment(.enjoy)
        }
        if title.contains(anyOf: ["meeting", "standup", "sync"]) {
            setEffort(.medium)
            setDuration(30)
        }
    }
}

private extension String {
    func contains(anyOf needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

/// OpenAI Chat Completions structured JSON enricher (BYOK). Fills only unset fields.
struct OpenAIEnricher: TaskEnriching {
    var apiKey: String
    var model: String = "gpt-4o-mini"
    var session: URLSession = .shared

    func enrich(
        _ draft: ParsedTaskDraft,
        completed: [PoolTask]
    ) async -> ParsedTaskDraft {
        guard draft.hasTitle else { return draft }
        // Skip network if everything is already filled.
        if draft.durationMinutes != nil, draft.effort != nil, draft.enjoyment != nil {
            return draft
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12

        let system = """
        You enrich personal task titles into structured estimates.
        Reply with ONLY compact JSON: {"effort":"quick|medium|big|null","enjoyment":"dread|meh|enjoy|null","durationMinutes":number|null}
        Prefer null over guessing wildly. durationMinutes should be 5–180.
        """
        let user = "Title: \(draft.title)"

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return draft
            }
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = root["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String,
                let payload = content.data(using: .utf8),
                let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
            else {
                return draft
            }
            return apply(json: json, to: draft)
        } catch {
            return draft
        }
    }

    private func apply(json: [String: Any], to draft: ParsedTaskDraft) -> ParsedTaskDraft {
        var next = draft
        if next.effort == nil, let raw = json["effort"] as? String {
            switch raw.lowercased() {
            case "quick": next.effort = .quick; next.effortSource = .ai
            case "medium": next.effort = .medium; next.effortSource = .ai
            case "big": next.effort = .big; next.effortSource = .ai
            default: break
            }
        }
        if next.enjoyment == nil, let raw = json["enjoyment"] as? String {
            switch raw.lowercased() {
            case "dread": next.enjoyment = .dread; next.enjoymentSource = .ai
            case "meh": next.enjoyment = .meh; next.enjoymentSource = .ai
            case "enjoy": next.enjoyment = .enjoy; next.enjoymentSource = .ai
            default: break
            }
        }
        if next.durationMinutes == nil {
            if let minutes = json["durationMinutes"] as? Int, (5...180).contains(minutes) {
                next.durationMinutes = minutes
                next.durationSource = .ai
            } else if let minutes = json["durationMinutes"] as? Double {
                let value = Int(minutes.rounded())
                if (5...180).contains(value) {
                    next.durationMinutes = value
                    next.durationSource = .ai
                }
            }
        }
        return next
    }
}

/// Stub for a second BYOK provider — same contract as OpenAI; wire when needed.
struct AnthropicEnricher: TaskEnriching {
    var apiKey: String

    func enrich(
        _ draft: ParsedTaskDraft,
        completed: [PoolTask]
    ) async -> ParsedTaskDraft {
        // Not shipped in this pass — fall through so Local + OpenAI remain the path.
        // Keeping the type documents the extension point for Anthropic Messages API.
        _ = apiKey
        return draft
    }
}

/// Local enrich first; optionally OpenAI (or future Anthropic) for leftover gaps.
struct CompositeTaskEnricher: TaskEnriching {
    var local: any TaskEnriching = LocalTaskEnricher()

    func enrich(
        _ draft: ParsedTaskDraft,
        completed: [PoolTask]
    ) async -> ParsedTaskDraft {
        var next = await local.enrich(draft, completed: completed)
        guard EnrichmentSettings.canUseAI else { return next }

        switch EnrichmentSettings.preferredProvider {
        case .openAI:
            guard let key = EnrichmentSettings.apiKey(for: .openAI) else { return next }
            next = await OpenAIEnricher(apiKey: key).enrich(next, completed: completed)
        case .anthropic:
            guard let key = EnrichmentSettings.apiKey(for: .anthropic) else { return next }
            next = await AnthropicEnricher(apiKey: key).enrich(next, completed: completed)
        }
        return next
    }
}
