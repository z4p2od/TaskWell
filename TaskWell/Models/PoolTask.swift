import Foundation
import SwiftData

/// Core pool task. Stable UUID + sync-friendly scalars so CloudKit can land later
/// without a schema rewrite. Do not enable CloudKit yet.
@Model
final class PoolTask {
    /// Stable identity across devices when sync is added.
    var id: UUID = UUID()

    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Optional due date; nil means no deadline.
    var dueDate: Date?

    /// EffortLevel.rawValue; nil means unset.
    var effortRaw: Int?

    /// EnjoymentLevel.rawValue; nil means unset.
    var enjoymentRaw: Int?

    /// Rough duration in minutes; nil means unset.
    var durationMinutes: Int?

    var isCompleted: Bool = false
    var completedAt: Date?

    /// Soft-hide until this date (suggest snooze). Nil means available.
    var snoozedUntil: Date?

    /// Reserved for future CloudKit / Watch conflict stamps.
    var schemaVersion: Int = 1

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        effort: EffortLevel? = nil,
        enjoyment: EnjoymentLevel? = nil,
        durationMinutes: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.effortRaw = effort?.rawValue
        self.enjoymentRaw = enjoyment?.rawValue
        self.durationMinutes = durationMinutes
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isCompleted = false
        self.completedAt = nil
        self.snoozedUntil = nil
        self.schemaVersion = 1
    }

    var effort: EffortLevel? {
        get { effortRaw.flatMap(EffortLevel.init(rawValue:)) }
        set {
            effortRaw = newValue?.rawValue
            touch()
        }
    }

    var enjoyment: EnjoymentLevel? {
        get { enjoymentRaw.flatMap(EnjoymentLevel.init(rawValue:)) }
        set {
            enjoymentRaw = newValue?.rawValue
            touch()
        }
    }

    func touch() {
        updatedAt = Date()
    }

    func markCompleted(at date: Date = Date()) {
        isCompleted = true
        completedAt = date
        snoozedUntil = nil
        touch()
    }

    func reopen() {
        isCompleted = false
        completedAt = nil
        touch()
    }

    func snooze(until date: Date) {
        snoozedUntil = date
        touch()
    }

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > Date()
    }

    var isOpen: Bool {
        !isCompleted
    }
}
