import Foundation

enum DueFilter: String, CaseIterable, Identifiable {
    case any
    case overdue
    case today
    case upcoming
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any due"
        case .overdue: "Overdue"
        case .today: "Due today"
        case .upcoming: "Upcoming"
        case .none: "No due date"
        }
    }
}

enum PoolStatusFilter: String, CaseIterable, Identifiable {
    case any
    case available
    case inProgress
    case snoozed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any status"
        case .available: "Available"
        case .inProgress: "In progress"
        case .snoozed: "Snoozed"
        }
    }
}

struct TaskPoolFilters: Equatable {
    var effort: EffortLevel?
    var enjoyment: EnjoymentLevel?
    var due: DueFilter = .any
    var status: PoolStatusFilter = .any

    var isActive: Bool {
        effort != nil || enjoyment != nil || due != .any || status != .any
    }

    /// When filtering to Snoozed alone, the Pool list should not also show a "Snoozed" section headline.
    var isSnoozedOnly: Bool {
        status == .snoozed
    }

    mutating func clear() {
        effort = nil
        enjoyment = nil
        due = .any
        status = .any
    }

    func matches(_ task: PoolTask, now: Date = Date()) -> Bool {
        if let effort, task.effort != effort { return false }
        if let enjoyment, task.enjoyment != enjoyment { return false }

        switch status {
        case .any:
            break
        case .available:
            if task.isActive || task.isSnoozed { return false }
        case .inProgress:
            if !task.isActive { return false }
        case .snoozed:
            if !task.isSnoozed { return false }
        }

        switch due {
        case .any:
            return true
        case .none:
            return task.dueDate == nil
        case .overdue:
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now
        case .today:
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        case .upcoming:
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= now && !Calendar.current.isDateInToday(dueDate)
        }
    }
}
