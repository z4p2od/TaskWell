import Foundation

/// Local heuristic scorer: due urgency + effort/duration match + enjoyment balance.
/// Presets keep prior behavior; Custom mood applies time + appetite dials.
struct LocalTaskScorer: TaskSuggesting {
    func suggest(
        from tasks: [PoolTask],
        mood: SuggestMood,
        excluding: Set<UUID>,
        now: Date = Date()
    ) -> PoolTask? {
        let context = SuggestScoreContext.make(mood: mood, now: now)
        let candidates = tasks.filter { task in
            task.isOpen
                && !task.isActive
                && !excluding.contains(task.id)
                && !task.isSnoozed
                && passesHardFilters(task, mood: mood)
        }

        guard !candidates.isEmpty else { return nil }

        let scored = candidates.map { ($0, score($0, context: context)) }

        let jittered = scored.map { task, score in
            let noise = mood.isSurprise
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
        total += effortMatchScore(task, mood: context.mood)
        total += durationMatchScore(task, mood: context.mood)
        total += enjoymentScore(task, mood: context.mood, dreadChance: context.dreadBoostChance)

        if context.mood.isImportant {
            total += importanceBoost(task.dueDate, now: context.now)
        }

        let ageDays = context.now.timeIntervalSince(task.createdAt) / 86_400
        total += min(ageDays * 0.4, 6)

        return total
    }

    // MARK: - Hard filters (Custom)

    private func passesHardFilters(_ task: PoolTask, mood: SuggestMood) -> Bool {
        guard case .custom(let dial) = mood else { return true }

        // Duration: if the task declares a length, it must roughly fit the window.
        if let minutes = task.durationMinutes, minutes > dial.minutesAvailable + 5 {
            return false
        }

        // Very low appetite: don't offer explicit Dread tasks at all.
        if dial.appetite < 0.2, task.enjoyment == .dread {
            return false
        }

        // Very low appetite also avoids Big effort when labeled.
        if dial.appetite < 0.25, task.effort == .big {
            return false
        }

        return true
    }

    // MARK: - Score pieces

    private func dueUrgencyScore(_ dueDate: Date?, now: Date) -> Double {
        guard let dueDate else { return 1 }

        let days = dueDate.timeIntervalSince(now) / 86_400

        if days < 0 { return 28 }
        if days < 1 { return 22 }
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

    private func effortMatchScore(_ task: PoolTask, mood: SuggestMood) -> Double {
        switch mood {
        case .preset(let preset):
            guard let preferred = preset.preferredEffort else {
                return task.effort == nil ? 2 : 4
            }
            guard let effort = task.effort else { return 6 }
            if effort == preferred { return 18 }
            if abs(effort.rawValue - preferred.rawValue) == 1 { return 8 }
            return 0

        case .custom(let dial):
            guard let effort = task.effort else { return 7 }
            // Low appetite → Quick; high → Big OK.
            let preferredRaw: Double = dial.appetite < 0.35 ? 0 : (dial.appetite < 0.7 ? 1 : 2)
            let distance = abs(Double(effort.rawValue) - preferredRaw)
            if distance < 0.1 { return 16 }
            if distance < 1.1 { return 8 }
            return dial.appetite > 0.7 ? 4 : 0
        }
    }

    private func durationMatchScore(_ task: PoolTask, mood: SuggestMood) -> Double {
        let ceiling: Int?
        switch mood {
        case .preset(let preset):
            ceiling = preset.durationCeiling
        case .custom(let dial):
            ceiling = dial.durationCeiling
        }

        guard let ceiling else { return 3 }
        guard let minutes = task.durationMinutes else {
            // Unknown duration: OK for custom, mild for presets.
            return 7
        }

        if minutes <= ceiling { return 16 }
        if minutes <= ceiling + 10 { return 6 }
        return -8
    }

    private func enjoymentScore(_ task: PoolTask, mood: SuggestMood, dreadChance: Double) -> Double {
        switch mood {
        case .preset:
            switch task.enjoyment {
            case .enjoy: return 10
            case .meh, .none: return 6
            case .dread:
                return Double.random(in: 0...1) < dreadChance ? 16 : 1
            }

        case .custom(let dial):
            switch task.enjoyment {
            case .enjoy:
                // Prefer enjoy when appetite is low; still fine when high.
                return dial.appetite < 0.4 ? 18 : 8
            case .meh, .none:
                return 8
            case .dread:
                // High appetite strongly surfaces dread; mid occasionally; low already filtered.
                if dial.appetite >= 0.75 { return 22 }
                if dial.appetite >= 0.5 {
                    return Double.random(in: 0...1) < dreadChance ? 14 : 3
                }
                return Double.random(in: 0...1) < dreadChance ? 8 : 0
            }
        }
    }
}
