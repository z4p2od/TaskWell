import SwiftUI

struct TaskRowView: View {
    let task: PoolTask
    /// When true, show an inline Unsnooze control (Pool snoozed section).
    var showsUnsnoozeButton: Bool = false
    var onUnsnooze: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(TaskWellTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if task.isActive {
                    Label("In progress", systemImage: "flag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaskWellTheme.coral)
                }

                HStack(spacing: 10) {
                    if let dueDate = task.dueDate {
                        Label(dueLabel(dueDate), systemImage: "calendar")
                            .foregroundStyle(dueColor(dueDate))
                    }
                    if let effort = task.effort {
                        Label(effort.title, systemImage: effort.symbolName)
                    }
                    if let enjoyment = task.enjoyment {
                        Label(enjoyment.title, systemImage: enjoyment.symbolName)
                    }
                    if let minutes = task.durationMinutes {
                        Label(durationLabel(minutes), systemImage: "clock")
                    }
                    if task.isSnoozed, let until = task.snoozedUntil {
                        Label("until \(snoozeLabel(until))", systemImage: "moon.zzz.fill")
                            .foregroundStyle(TaskWellTheme.muted)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(TaskWellTheme.muted)
                .lineLimit(task.isSnoozed ? 2 : 1)
            }

            if showsUnsnoozeButton, task.isSnoozed {
                Spacer(minLength: 8)
                Button("Unsnooze") {
                    onUnsnooze?()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaskWellTheme.coral)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes == 120 { return "2h+" }
        return DurationFormatting.label(minutes: minutes)
    }

    private func snoozeLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func dueLabel(_ date: Date) -> String {
        if date < Date() { return "Overdue" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dueColor(_ date: Date) -> Color {
        if date < Date() { return TaskWellTheme.coral }
        if Calendar.current.isDateInToday(date) { return TaskWellTheme.wellDeep }
        return TaskWellTheme.muted
    }
}
