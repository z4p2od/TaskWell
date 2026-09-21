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

    /// Optional free-text blob used at capture (for learning / debug).
    var rawCaptureText: String?

    /// Optional due date; nil means no deadline.
    var dueDate: Date?

    /// Estimated effort at capture (EffortLevel.rawValue).
    var effortRaw: Int?

    /// Estimated enjoyment at capture (EnjoymentLevel.rawValue).
    var enjoymentRaw: Int?

    /// Estimated duration in minutes at capture.
    var durationMinutes: Int?

    /// Completion truth — minutes actually taken (from Done confirm).
    var actualDurationMinutes: Int?

    /// Completion truth — effort felt (EffortLevel.rawValue).
    var actualEffortRaw: Int?

    /// Completion truth — enjoyment felt (EnjoymentLevel.rawValue).
    var actualEnjoymentRaw: Int?

    var isCompleted: Bool = false
    var completedAt: Date?

    /// User accepted this suggestion and is working on it. Not completed yet.
    var isActive: Bool = false
    var acceptedAt: Date?

    /// Soft-hide until this date (suggest snooze). Nil means available.
    var snoozedUntil: Date?

    /// Reserved for future CloudKit / Watch conflict stamps.
    var schemaVersion: Int = 2

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        effort: EffortLevel? = nil,
        enjoyment: EnjoymentLevel? = nil,
        durationMinutes: Int? = nil,
        rawCaptureText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.effortRaw = effort?.rawValue
        self.enjoymentRaw = enjoyment?.rawValue
        self.durationMinutes = durationMinutes
        self.rawCaptureText = rawCaptureText
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.actualDurationMinutes = nil
        self.actualEffortRaw = nil
        self.actualEnjoymentRaw = nil
        self.isCompleted = false
        self.completedAt = nil
        self.isActive = false
        self.acceptedAt = nil
        self.snoozedUntil = nil
        self.schemaVersion = 2
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

    var actualEffort: EffortLevel? {
        get { actualEffortRaw.flatMap(EffortLevel.init(rawValue:)) }
        set {
            actualEffortRaw = newValue?.rawValue
            touch()
        }
    }

    var actualEnjoyment: EnjoymentLevel? {
        get { actualEnjoymentRaw.flatMap(EnjoymentLevel.init(rawValue:)) }
        set {
            actualEnjoymentRaw = newValue?.rawValue
            touch()
        }
    }

    /// Prefer completion truth for learning; fall back to capture estimates.
    var learnedDurationMinutes: Int? {
        actualDurationMinutes ?? durationMinutes
    }

    var learnedEffort: EffortLevel? {
        actualEffort ?? effort
    }

    var learnedEnjoyment: EnjoymentLevel? {
        actualEnjoyment ?? enjoyment
    }

    func touch() {
        updatedAt = Date()
    }

    /// Update capture fields only — does not change active or completed state.
    func applyDetails(
        title: String,
        dueDate: Date?,
        effort: EffortLevel?,
        enjoyment: EnjoymentLevel?,
        durationMinutes: Int?
    ) {
        self.title = title
        self.dueDate = dueDate
        self.effortRaw = effort?.rawValue
        self.enjoymentRaw = enjoyment?.rawValue
        self.durationMinutes = durationMinutes
        touch()
    }

    /// Accept = commit / start. Does **not** complete the task.
    func markAccepted(at date: Date = Date()) {
        isActive = true
        acceptedAt = date
        snoozedUntil = nil
        touch()
    }

    /// Put an accepted task back in the pool without completing it.
    func clearActive() {
        isActive = false
        acceptedAt = nil
        touch()
    }

    /// Done = actually finished, with optional completion truth for learning.
    func markCompleted(
        at date: Date = Date(),
        actualDurationMinutes: Int? = nil,
        actualEffort: EffortLevel? = nil,
        actualEnjoyment: EnjoymentLevel? = nil
    ) {
        isCompleted = true
        completedAt = date
        isActive = false
        acceptedAt = nil
        snoozedUntil = nil
        if let actualDurationMinutes {
            self.actualDurationMinutes = actualDurationMinutes
        }
        if let actualEffort {
            self.actualEffortRaw = actualEffort.rawValue
        }
        if let actualEnjoyment {
            self.actualEnjoymentRaw = actualEnjoyment.rawValue
        }
        touch()
    }

    func reopen() {
        isCompleted = false
        completedAt = nil
        isActive = false
        acceptedAt = nil
        // Keep actual* for history even if reopened? Clear so a new Done pass re-asks.
        actualDurationMinutes = nil
        actualEffortRaw = nil
        actualEnjoymentRaw = nil
        touch()
    }

    func snooze(until date: Date) {
        snoozedUntil = date
        isActive = false
        acceptedAt = nil
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

extension PoolTask: Identifiable {}
