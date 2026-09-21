import Foundation

/// Manual dials for Custom mood: time available + appetite for hard/dreaded work.
struct CustomSuggestDial: Equatable, Sendable {
    /// Minutes the user has right now.
    var minutesAvailable: Int
    /// 0 = go easy (prefer Enjoy / Quick); 1 = willing to take Dread / Big work.
    var appetite: Double

    static let minutesRange = 5...180
    static let `default` = CustomSuggestDial(minutesAvailable: 30, appetite: 0.35)

    init(minutesAvailable: Int = 30, appetite: Double = 0.35) {
        self.minutesAvailable = min(max(minutesAvailable, Self.minutesRange.lowerBound), Self.minutesRange.upperBound)
        self.appetite = min(max(appetite, 0), 1)
    }

    /// Spectrum label for the appetite dial.
    var appetiteLabel: String {
        switch appetite {
        case ..<0.2: "Go easy on me"
        case ..<0.4: "Keep it light"
        case ..<0.6: "Balanced — mix it up"
        case ..<0.8: "I can dig into something"
        default: "Not bored — I’ll take a dread"
        }
    }

    var shortAppetiteLabel: String {
        switch appetite {
        case ..<0.2: "Go easy"
        case ..<0.4: "Keep light"
        case ..<0.6: "Balanced"
        case ..<0.8: "Can dig in"
        default: "Take a dread"
        }
    }

    var cardEyebrow: String {
        "\(minutesAvailable) min · \(shortAppetiteLabel)"
    }

    /// Soft ceiling used for duration matching (same as minutes available).
    var durationCeiling: Int { minutesAvailable }

    /// Chance / weight toward surfacing dread — rises with appetite.
    var dreadWeight: Double {
        // Low appetite almost never; high appetite strongly favors dread.
        switch appetite {
        case ..<0.25: 0.02
        case ..<0.5: 0.12
        case ..<0.75: 0.35
        default: 0.85
        }
    }
}

/// What the user asked the well for — a named preset or custom dials.
enum SuggestMood: Equatable, Sendable {
    case preset(SuggestPreset)
    case custom(CustomSuggestDial)

    var displayTitle: String {
        switch self {
        case .preset(let preset): preset.title
        case .custom(let dial): dial.cardEyebrow
        }
    }

    var isSurprise: Bool {
        if case .preset(.surpriseMe) = self { return true }
        return false
    }

    var isImportant: Bool {
        if case .preset(.important) = self { return true }
        return false
    }
}
