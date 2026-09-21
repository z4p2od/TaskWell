import Foundation

/// Local heuristic scorer: due urgency + effort/duration match + enjoyment balance.
/// Occasionally boosts a dreaded task so they don't pile up unused.
struct LocalTaskScorer: TaskSuggesting {
    func suggest(
        from tasks: [PoolTask],
        preset: SuggestPreset,
        excluding: Set<UUID>,
        now: Date = Date()
    ) -> PoolTask? {
        let candidates = tasks.filter { task in
            task.isOpen
                && !task.isActive
                && !excluding.contains(task.id)
                && !task.isSnoozed
        }

        guard !candidates.isEmpty else { return nil }

        let context = SuggestScoreContext.default(preset: preset, now: now)
        let scored = candidates.map { ($0, score($0, context: context)) }

        // Slight jitter so "Surprise me" and ties feel alive without chaos.
        let jittered = scored.map { task, score in
            let noise = preset == .surpriseMe
                ? Double.random(in: 0...8)
                : Double.random(in: 0...1.5)
            return (task, score + noise)
        }

        return jittered.max(by: { $0.1 < $1.1 })?.0
    }

    /// Exposed for tests / debugging.
    func score(_ task: PoolTask, context: SuggestScoreContext) -> Double {
        var total: Double = 0

        total += dueUrgencyScore(task.dueDate, now: context.now)
        total += effortMatchScore(task, preset: context.preset)
        total += durationMatchScore(task, preset: context.preset)
        total += enjoymentBalanceScore(task, chance: context.dreadBoostChance)

        if context.preset == .important {
            total += importanceBoost(task.dueDate, now: context.now)
        }

        // Older open tasks gently float up so nothing stagnates forever.
        let ageDays = context.now.timeIntervalSince(task.createdAt) / 86_400
        total += min(ageDays * 0.4, 6)

        return total
    }

    private func dueUrgencyScore(_ dueDate: Date?, now: Date) -> Double {
        guard let dueDate else { return 1 }

        let seconds = dueDate.timeIntervalSince(now)
        let days = seconds / 86_400

        if days < 0 { return 28 }          // overdue
        if days < 1 { return 22 }          // due today
        if days < 2 { return 16 }
        if days < 5 { return 10 }
        if days < 14 { return 5 }
        return 2
    }

    private func importanceBoost(_ dueDate: Date?, now: Date) -> Double {
        guard let dueDate else { return 0 }
        let days = dueDate.timeIntervalSince(now) / 86_400
        if days < 0 { return 18 }
        if days < 2 { return 12 }
        if days < 7 { return 6 }
        return 0
    }

    private func effortMatchScore(_ task: PoolTask, preset: SuggestPreset) -> Double {
        guard let preferred = preset.preferredEffort else {
            return task.effort == nil ? 2 : 4
        }
        guard let effort = task.effort else { return 6 } // unset = flexible

        if effort == preferred { return 18 }
        if abs(effort.rawValue - preferred.rawValue) == 1 { return 8 }
        return 0
    }

    private func durationMatchScore(_ task: PoolTask, preset: SuggestPreset) -> Double {
        guard let ceiling = preset.durationCeiling else { return 3 }
        guard let minutes = task.durationMinutes else { return 7 }

        if minutes <= ceiling { return 14 }
        if minutes <= ceiling + 15 { return 5 }
        return -4
    }

    private func enjoymentBalanceScore(_ task: PoolTask, chance: Double) -> Double {
        switch task.enjoyment {
        case .enjoy:
            return 10
        case .meh, .none:
            return 6
        case .dread:
            // Occasionally surface dread so it doesn't accumulate.
            return Double.random(in: 0...1) < chance ? 16 : 1
        }
    }
}
