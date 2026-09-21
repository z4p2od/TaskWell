import Foundation

/// Swap-ready suggest engine. Local scorer today; AI / calendar / location later.
protocol TaskSuggesting {
    func suggest(
        from tasks: [PoolTask],
        mood: SuggestMood,
        excluding: Set<UUID>,
        now: Date
    ) -> PoolTask?
}

/// Context for scoring — kept separate so future engines can reuse the same inputs.
struct SuggestScoreContext: Sendable {
    var mood: SuggestMood
    var now: Date
    /// Baseline chance to boost a dreaded task (presets). Custom uses dial.dreadWeight instead.
    var dreadBoostChance: Double
}

extension SuggestScoreContext {
    static func make(mood: SuggestMood, now: Date = Date()) -> SuggestScoreContext {
        let chance: Double
        switch mood {
        case .preset:
            chance = 0.22
        case .custom(let dial):
            chance = dial.dreadWeight
        }
        return SuggestScoreContext(mood: mood, now: now, dreadBoostChance: chance)
    }
}
