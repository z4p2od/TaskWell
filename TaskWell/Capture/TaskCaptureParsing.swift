import Foundation

/// Mutable draft produced by free-text parsing (and chip tweaks) before save.
struct ParsedTaskDraft: Equatable, Sendable {
    var title: String = ""
    var dueDate: Date?
    var durationMinutes: Int?
    var effort: EffortLevel?
    var enjoyment: EnjoymentLevel?

    /// Which fields came from parse vs similarity fill (for chip styling).
    var titleSource: FieldSource = .unset
    var dueSource: FieldSource = .unset
    var durationSource: FieldSource = .unset
    var effortSource: FieldSource = .unset
    var enjoymentSource: FieldSource = .unset

    enum FieldSource: String, Sendable {
        case unset
        case parsed
        case similar
        case enriched
        case ai
        case manual
    }

    var hasTitle: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Swap-ready free-text → draft parser (native today; LLM later).
protocol TaskCaptureParsing: Sendable {
    func parse(_ text: String, now: Date) -> ParsedTaskDraft
}

/// Suggest missing capture fields from similar completed tasks.
protocol CompletionDefaultsSuggesting {
    func suggestDefaults(
        forTitle title: String,
        from completed: [PoolTask]
    ) -> CompletionDefaultsSuggestion
}

struct CompletionDefaultsSuggestion: Equatable, Sendable {
    var durationMinutes: Int?
    var effort: EffortLevel?
    var enjoyment: EnjoymentLevel?
    var matchedTitle: String?
}
