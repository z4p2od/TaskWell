import Foundation

/// Swap-ready suggest engine. Local scorer today; AI / calendar / location later.
protocol TaskSuggesting {
    func suggest(
        from tasks: [PoolTask],
        preset: SuggestPreset,
        excluding: Set<UUID>,
        now: Date
    ) -> PoolTask?
}

/// Context for scoring — kept separate so future engines can reuse the same inputs.
struct SuggestScoreContext: Sendable {
    var preset: SuggestPreset
    var now: Date
    var dreadBoostChance: Double
}

extension SuggestScoreContext {
    static func `default`(preset: SuggestPreset, now: Date = Date()) -> SuggestScoreContext {
        SuggestScoreContext(preset: preset, now: now, dreadBoostChance: 0.22)
    }
}
