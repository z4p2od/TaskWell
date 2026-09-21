import SwiftUI

struct SuggestCardView: View {
    let task: PoolTask
    let preset: SuggestPreset
    var onAccept: () -> Void
    var onSkip: () -> Void
    var onSnooze: () -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                Text(preset.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(TaskWellTheme.well.opacity(0.9))

                Text(task.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                FlowTags(task: task)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(TaskWellTheme.well.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: TaskWellTheme.ink.opacity(0.08), radius: 24, y: 12)
            .scaleEffect(appear ? 1 : 0.96)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryWellButtonStyle())

                Button(action: onSnooze) {
                    Label("Snooze", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryWellButtonStyle())
            }
            .padding(.top, 18)

            Button(action: onAccept) {
                Label("Accept", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(TaskWellTheme.well)
            .controlSize(.large)
            .padding(.top, 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appear = true
            }
        }
        .onChange(of: task.id) { _, _ in
            appear = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }
}

private struct FlowTags: View {
    let task: PoolTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dueDate = task.dueDate {
                tag(dueLabel(dueDate), "calendar")
            }
            HStack(spacing: 8) {
                if let effort = task.effort {
                    tag(effort.title, effort.symbolName)
                }
                if let enjoyment = task.enjoyment {
                    tag(enjoyment.title, enjoyment.symbolName)
                }
                if let minutes = task.durationMinutes {
                    tag("\(minutes) min", "clock")
                }
            }
        }
    }

    private func tag(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TaskWellTheme.mist, in: Capsule())
            .foregroundStyle(TaskWellTheme.wellDeep)
    }

    private func dueLabel(_ date: Date) -> String {
        if date < Date() { return "Overdue" }
        if Calendar.current.isDateInToday(date) { return "Due today" }
        return "Due \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct SecondaryWellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .foregroundStyle(TaskWellTheme.ink)
            .background(
                TaskWellTheme.sand.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}
