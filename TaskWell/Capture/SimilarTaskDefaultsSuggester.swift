import Foundation

/// Local similarity helper: keyword overlap against completed tasks' learned fields.
/// Swap-ready behind `CompletionDefaultsSuggesting` for smarter rankers later.
struct SimilarTaskDefaultsSuggester: CompletionDefaultsSuggesting {
    var minimumScore: Double = 0.18

    func suggestDefaults(
        forTitle title: String,
        from completed: [PoolTask]
    ) -> CompletionDefaultsSuggestion {
        let query = tokens(from: title)
        guard !query.isEmpty else { return CompletionDefaultsSuggestion() }

        var best: (score: Double, task: PoolTask)?
        for task in completed where task.isCompleted {
            let score = jaccard(query, tokens(from: task.title))
            if score >= minimumScore {
                if best == nil || score > best!.score {
                    best = (score, task)
                }
            }
        }

        guard let best else { return CompletionDefaultsSuggestion() }

        return CompletionDefaultsSuggestion(
            durationMinutes: best.task.learnedDurationMinutes,
            effort: best.task.learnedEffort,
            enjoyment: best.task.learnedEnjoyment,
            matchedTitle: best.task.title
        )
    }

    private func tokens(from text: String) -> Set<String> {
        let lowered = text.lowercased()
        let parts = lowered.split { !$0.isLetter && !$0.isNumber }
        let stop: Set<String> = [
            "a", "an", "the", "to", "of", "and", "or", "for", "in", "on", "at",
            "my", "me", "i", "it", "this", "that", "with", "from", "about"
        ]
        return Set(parts.map(String.init).filter { $0.count > 1 && !stop.contains($0) })
    }

    private func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = a.intersection(b).count
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(inter) / Double(union)
    }
}
