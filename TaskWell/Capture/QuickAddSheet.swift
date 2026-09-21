import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var effort: EffortLevel?
    @State private var enjoyment: EnjoymentLevel?
    @State private var durationMinutes: Int?
    @State private var saveError: String?

    private let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                } header: {
                    Text("Task")
                } footer: {
                    Text("Title is enough. Everything else is optional.")
                }

                Section("Optional details") {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Picker("Effort", selection: $effort) {
                        Text("Not set").tag(Optional<EffortLevel>.none)
                        ForEach(EffortLevel.allCases) { level in
                            Label(level.title, systemImage: level.symbolName)
                                .tag(Optional(level))
                        }
                    }

                    Picker("Enjoyment", selection: $enjoyment) {
                        Text("Not set").tag(Optional<EnjoymentLevel>.none)
                        ForEach(EnjoymentLevel.allCases) { level in
                            Label(level.title, systemImage: level.symbolName)
                                .tag(Optional(level))
                        }
                    }

                    Picker("Rough duration", selection: $durationMinutes) {
                        Text("Not set").tag(Optional<Int>.none)
                        ForEach(durationChoices, id: \.self) { minutes in
                            Text(durationLabel(minutes)).tag(Optional(minutes))
                        }
                    }
                }

                if let saveError {
                    Section {
                        ErrorBanner(message: saveError) {
                            self.saveError = nil
                            save()
                        }
                    }
                }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours) hr" : "\(hours) hr \(rem) min"
    }

    private func save() {
        let clean = trimmedTitle
        guard !clean.isEmpty else {
            saveError = "Add a short title so this task can find its way back."
            return
        }

        let task = PoolTask(
            title: clean,
            dueDate: hasDueDate ? dueDate : nil,
            effort: effort,
            enjoyment: enjoyment,
            durationMinutes: durationMinutes
        )

        do {
            modelContext.insert(task)
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Couldn’t save that task. Check storage and try again."
        }
    }
}
