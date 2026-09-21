import Foundation

/// On-device free-text parser: heuristics + `NSDataDetector` (no cloud LLM).
struct NativeTaskCaptureParser: TaskCaptureParsing {
    func parse(_ text: String, now: Date = Date()) -> ParsedTaskDraft {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var draft = ParsedTaskDraft()
        guard !working.isEmpty else { return draft }

        // Order matters: strip structured cues first, then date, then title is remainder.
        if let (minutes, range) = extractDuration(from: working) {
            draft.durationMinutes = minutes
            draft.durationSource = .parsed
            working = working.removingSubrange(range)
        }

        if let (effort, range) = extractEffort(from: working) {
            draft.effort = effort
            draft.effortSource = .parsed
            working = working.removingSubrange(range)
        }

        if let (enjoyment, range) = extractEnjoyment(from: working) {
            draft.enjoyment = enjoyment
            draft.enjoymentSource = .parsed
            working = working.removingSubrange(range)
        }

        if let (date, range) = extractDueDate(from: working, now: now) {
            draft.dueDate = date
            draft.dueSource = .parsed
            working = working.removingSubrange(range)
        }

        let title = cleanTitle(working)
        if !title.isEmpty {
            draft.title = title
            draft.titleSource = .parsed
        }

        return draft
    }

    // MARK: - Duration

    private func extractDuration(from text: String) -> (Int, Range<String.Index>)? {
        let patterns: [(String, (NSTextCheckingResult, NSString) -> Int?)] = [
            (#"(?i)(?:~|about|around|roughly)?\s*(\d{1,3})\s*(?:minutes?|mins?|m)\b"#, { m, s in
                Int(s.substring(with: m.range(at: 1)))
            }),
            (#"(?i)(?:~|about|around)?\s*(\d{1,2}(?:\.\d)?)\s*(?:hours?|hrs?|h)\b"#, { m, s in
                guard let hours = Double(s.substring(with: m.range(at: 1))) else { return nil }
                return Int((hours * 60).rounded())
            }),
            (#"(?i)\bhalf\s*(?:an?\s*)?hour\b"#, { _, _ in 30 }),
            (#"(?i)\ban?\s*hour\b"#, { _, _ in 60 }),
            (#"(?i)\bquarter\s*(?:of\s*)?(?:an?\s*)?hour\b"#, { _, _ in 15 })
        ]

        let ns = text as NSString
        for (pattern, value) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let full = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: text, range: full),
               let minutes = value(match, ns),
               minutes > 0,
               let range = Range(match.range, in: text) {
                return (min(minutes, 8 * 60), range)
            }
        }
        return nil
    }

    // MARK: - Effort

    private func extractEffort(from text: String) -> (EffortLevel, Range<String.Index>)? {
        let map: [(EffortLevel, String)] = [
            (.quick, #"(?i)\b(?:quick|easy|small|tiny|light|fast)\b"#),
            (.big, #"(?i)\b(?:big|huge|large|heavy|major|long)\s*(?:task|job|one)?\b"#),
            (.medium, #"(?i)\b(?:medium|moderate|mid)\b"#)
        ]
        return firstKeywordMatch(in: text, map: map)
    }

    // MARK: - Enjoyment

    private func extractEnjoyment(from text: String) -> (EnjoymentLevel, Range<String.Index>)? {
        // Longer phrases first so “I dread this” doesn’t leave a stray “I”.
        let map: [(EnjoymentLevel, String)] = [
            (.dread, #"(?i)\bi\s+dread(?:\s+this)?\b"#),
            (.dread, #"(?i)\b(?:dread|dreading|hate|hates|awful|sucks?|ugh|gross|painful)\b"#),
            (.enjoy, #"(?i)\bi\s+(?:enjoy|love)\s+(?:this|it)?\b"#),
            (.enjoy, #"(?i)\b(?:enjoy|fun|love|loves|looking\s+forward|nice|pleasant)\b"#),
            (.meh, #"(?i)\b(?:meh|blah|whatever|fine|ok(?:ay)?)\b"#)
        ]
        return firstKeywordMatch(in: text, map: map)
    }

    private func firstKeywordMatch<T>(
        in text: String,
        map: [(T, String)]
    ) -> (T, Range<String.Index>)? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        for (value, pattern) in map {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: full),
               let range = Range(match.range, in: text) {
                return (value, range)
            }
        }
        return nil
    }

    // MARK: - Due date

    private func extractDueDate(from text: String, now: Date) -> (Date, Range<String.Index>)? {
        let cal = Calendar.current
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        // Relative words first (more intentional than random detector hits).
        let relative: [(String, (Date) -> Date?)] = [
            (#"(?i)\btonight\b"#, { date in
                cal.date(bySettingHour: 20, minute: 0, second: 0, of: date)
            }),
            (#"(?i)\btoday\b"#, { date in
                cal.date(bySettingHour: 17, minute: 0, second: 0, of: date)
            }),
            (#"(?i)\btomorrow\b"#, { date in
                guard let next = cal.date(byAdding: .day, value: 1, to: date) else { return nil }
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: next)
            }),
            (#"(?i)\bnext\s+week\b"#, { date in
                guard let next = cal.date(byAdding: .day, value: 7, to: date) else { return nil }
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: next)
            })
        ]

        for (pattern, builder) in relative {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: full),
               let range = Range(match.range, in: text),
               let date = builder(now) {
                return (date, range)
            }
        }

        // Weekday names: “Friday”, “this Friday”, “next Monday”
        let weekdays: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7)
        ]
        for (name, weekday) in weekdays {
            let pattern = #"(?i)\b(?:this\s+|next\s+)?\#(name)\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: full),
               let range = Range(match.range, in: text) {
                let matched = String(text[range]).lowercased()
                let preferNext = matched.contains("next")
                if let date = nextWeekday(weekday, from: now, preferNextWeek: preferNext) {
                    return (date, range)
                }
            }
        }

        // NSDataDetector for absolute-ish dates / times.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            if let match = detector.firstMatch(in: text, range: full),
               match.resultType.contains(.date),
               let date = match.date,
               let range = Range(match.range, in: text) {
                return (date, range)
            }
        }

        return nil
    }

    private func nextWeekday(_ weekday: Int, from now: Date, preferNextWeek: Bool) -> Date? {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = 9
        comps.minute = 0
        let match = cal.nextDate(
            after: now,
            matching: comps,
            matchingPolicy: .nextTime,
            direction: .forward
        )
        guard let match else { return nil }
        if preferNextWeek {
            return cal.date(byAdding: .day, value: 7, to: match)
        }
        // If “Friday” and today is Friday morning, nextDate may be next week already — OK.
        return match
    }

    // MARK: - Title cleanup

    private func cleanTitle(_ text: String) -> String {
        var t = text
        let junk = [
            #"(?i)^[,;.\-–—:/]+"#,
            #"(?i)[,;.\-–—:/]+$"#,
            #"(?i),(\s*,)+"#,
            #"(?i)\bi\s+(?:need\s+to|have\s+to|gotta|should|must)\s+"#,
            #"(?i)\bplease\b"#,
            #"(?i)\bthis\s*$"#,
            #"(?i)\bit\s*$"#,
            #"(?i)\bi\s*$"#
        ]
        for pattern in junk {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: (t as NSString).length)
                let template = pattern.contains(",(\\s*,)") ? "," : " "
                t = regex.stringByReplacingMatches(in: t, range: range, withTemplate: template)
            }
        }
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+,|,+\s*"#, with: ", ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;.")))
        if t.isEmpty { return "" }
        return t.prefix(1).uppercased() + t.dropFirst()
    }
}

private extension String {
    func removingSubrange(_ range: Range<String.Index>) -> String {
        var copy = self
        copy.removeSubrange(range)
        return copy.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
