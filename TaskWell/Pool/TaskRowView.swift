import SwiftUI

struct TaskRowView: View {
    let task: PoolTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.body.weight(.medium))
                .foregroundStyle(TaskWellTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if task.isActive {
                    Label("In progress", systemImage: "flag.fill")
                        .foregroundStyle(TaskWellTheme.coral)
                }
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
                    Label("\(minutes)m", systemImage: "clock")
                }
                if task.isSnoozed {
                    Label("Snoozed", systemImage: "moon.zzz.fill")
                        .foregroundStyle(TaskWellTheme.muted)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(TaskWellTheme.muted)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
