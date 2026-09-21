import SwiftUI
import SwiftData

/// Shared create / edit sheet for pool tasks. Editing never toggles active or completed.
struct TaskEditorSheet: View {
    enum Mode {
        case create
        case edit(PoolTask)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var effort: EffortLevel?
    @State private var enjoyment: EnjoymentLevel?
    @State private var durationMinutes: Int?
    @State private var saveError: String?

    @FocusState private var titleFocused: Bool

    private let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    init(mode: Mode = .create) {
        self.mode = mode
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _dueDate = State(initialValue: Date())
            _hasDueDate = State(initialValue: false)
            _effort = State(initialValue: nil)
            _enjoyment = State(initialValue: nil)
            _durationMinutes = State(initialValue: nil)
        case .edit(let task):
            _title = State(initialValue: task.title)
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _hasDueDate = State(initialValue: task.dueDate != nil)
            _effort = State(initialValue: task.effort)
            _enjoyment = State(initialValue: task.enjoyment)
            _durationMinutes = State(initialValue: task.durationMinutes)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title, axis: .vertical)
                        .font(.body)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($titleFocused)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .onTapGesture { titleFocused = true }
                } header: {
                    Text("Task")
                } footer: {
                    Text(
                        isEditing
                            ? "Changes update this task only — they won’t mark it Done or start it."
                            : "Title is enough. Everything else is optional."
                    )
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
            .navigationTitle(isEditing ? "Edit task" : "Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onAppear {
                // Delay one run-loop so the sheet presentation finishes, then open the keyboard.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    titleFocused = true
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
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

        do {
            switch mode {
            case .create:
                let task = PoolTask(
                    title: clean,
                    dueDate: hasDueDate ? dueDate : nil,
                    effort: effort,
                    enjoyment: enjoyment,
                    durationMinutes: durationMinutes
                )
                modelContext.insert(task)
            case .edit(let task):
                task.applyDetails(
                    title: clean,
                    dueDate: hasDueDate ? dueDate : nil,
                    effort: effort,
                    enjoyment: enjoyment,
                    durationMinutes: durationMinutes
                )
            }
            try modelContext.save()
            dismiss()
        } catch {
            saveError = isEditing
                ? "Couldn’t save your changes. Try again."
                : "Couldn’t save that task. Check storage and try again."
        }
    }
}

/// Back-compat name used by existing call sites for create-only.
typealias QuickAddSheet = TaskEditorSheet
