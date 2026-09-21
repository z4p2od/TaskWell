import SwiftUI

/// Confirm how the task actually felt before it lands in Done history.
struct DoneConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss

    let task: PoolTask
    var onConfirm: (_ duration: Int?, _ effort: EffortLevel?, _ enjoyment: EnjoymentLevel?) -> Void

    @State private var durationMinutes: Int?
    @State private var effort: EffortLevel?
    @State private var enjoyment: EnjoymentLevel?

    private let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180]

    init(
        task: PoolTask,
        onConfirm: @escaping (_ duration: Int?, _ effort: EffortLevel?, _ enjoyment: EnjoymentLevel?) -> Void
    ) {
        self.task = task
        self.onConfirm = onConfirm
        _durationMinutes = State(initialValue: task.durationMinutes)
        _effort = State(initialValue: task.effort)
        _enjoyment = State(initialValue: task.enjoyment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TaskWellTheme.ink)
                } header: {
                    Text("Finished")
                } footer: {
                    Text("Confirm how it actually went. This trains better defaults next time you capture similar work.")
                }

                Section("How it felt") {
                    Picker("Minutes taken", selection: $durationMinutes) {
                        Text("Skip").tag(Optional<Int>.none)
                        ForEach(durationChoices, id: \.self) { minutes in
                            Text(durationLabel(minutes)).tag(Optional(minutes))
                        }
                    }

                    Picker("Effort felt", selection: $effort) {
                        Text("Skip").tag(Optional<EffortLevel>.none)
                        ForEach(EffortLevel.allCases) { level in
                            Label(level.title, systemImage: level.symbolName)
                                .tag(Optional(level))
                        }
                    }

                    Picker("Enjoyment felt", selection: $enjoyment) {
                        Text("Skip").tag(Optional<EnjoymentLevel>.none)
                        ForEach(EnjoymentLevel.allCases) { level in
                            Label(level.title, systemImage: level.symbolName)
                                .tag(Optional(level))
                        }
                    }
                }
            }
            .navigationTitle("Mark Done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Done") {
                        onConfirm(durationMinutes, effort, enjoyment)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours) hr" : "\(hours) hr \(rem) min"
    }
}
