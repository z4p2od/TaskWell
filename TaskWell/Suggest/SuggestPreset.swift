import Foundation

/// Presets the user picks before the one-card suggest flow.
enum SuggestPreset: String, CaseIterable, Identifiable, Sendable {
    case easyWin
    case thirtyMinutes
    case important
    case surpriseMe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easyWin: "Easy win"
        case .thirtyMinutes: "~30 min"
        case .important: "Important"
        case .surpriseMe: "Surprise me"
        }
    }

    var subtitle: String {
        switch self {
        case .easyWin: "Something light to get moving"
        case .thirtyMinutes: "Fits a short block of time"
        case .important: "Due soon or overdue"
        case .surpriseMe: "Let the well pick for you"
        }
    }

    var symbolName: String {
        switch self {
        case .easyWin: "sparkles"
        case .thirtyMinutes: "timer"
        case .important: "exclamationmark.circle.fill"
        case .surpriseMe: "shuffle"
        }
    }

    /// Preferred effort when matching. Nil means no preference.
    var preferredEffort: EffortLevel? {
        switch self {
        case .easyWin: .quick
        case .thirtyMinutes: .medium
        case .important: nil
        case .surpriseMe: nil
        }
    }

    /// Soft duration ceiling in minutes. Nil means none.
    var durationCeiling: Int? {
        switch self {
        case .easyWin: 20
        case .thirtyMinutes: 35
        case .important: nil
        case .surpriseMe: nil
        }
    }
}
