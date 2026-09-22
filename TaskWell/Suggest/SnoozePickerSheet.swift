import SwiftUI

/// Choose when a task should re-enter Suggest.
struct SnoozePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let taskTitle: String
    var onSnooze: (Date) -> Void

    @State private var selection: SnoozePreset = .fourHours
    @State private var customDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var showCustomPicker = false

    enum SnoozePreset: String, CaseIterable, Identifiable {
        case oneHour
        case fourHours
        case tonight
        case tomorrowMorning
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .oneHour: "1 hour"
            case .fourHours: "4 hours"
            case .tonight: "Tonight"
            case .tomorrowMorning: "Tomorrow morning"
            case .custom: "Pick date & time…"
            }
        }

        var symbolName: String {
            switch self {
            case .oneHour, .fourHours: "clock"
            case .tonight: "moon.stars"
            case .tomorrowMorning: "sunrise"
            case .custom: "calendar"
            }
        }

        func resolve(now: Date = Date(), custom: Date) -> Date {
            let cal = Calendar.current
            switch self {
            case .oneHour:
                return cal.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
            case .fourHours:
                return cal.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
            case .tonight:
                let tonight = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now)
                    ?? now.addingTimeInterval(3600)
                if tonight > now { return tonight }
                let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
                return cal.date(bySettingHour: 20, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            case .tomorrowMorning:
                let next = cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: next) ?? next
            case .custom:
                return max(custom, now.addingTimeInterval(5 * 60))
            }
        }

        func subtitle(now: Date = Date(), custom: Date) -> String {
            let date = resolve(now: now, custom: custom)
            switch self {
            case .oneHour, .fourHours:
                return date.formatted(date: .omitted, time: .shortened)
            case .tonight:
                let date = resolve(now: now, custom: custom)
                if Calendar.current.isDateInToday(date) {
                    return "8:00 PM"
                }
                return "Tomorrow 8:00 PM"
            case .tomorrowMorning:
                return "9:00 AM"
            case .custom:
                return date.formatted(date: .abbreviated, time: .shortened)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(taskTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(TaskWellTheme.ink)
                } header: {
                    Text("Task")
                }

                Section {
                    ForEach(SnoozePreset.allCases) { preset in
                        Button {
                            if preset == .custom {
                                selection = .custom
                                showCustomPicker = true
                            } else {
                                selection = preset
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: preset.symbolName)
                                    .foregroundStyle(TaskWellTheme.well)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .foregroundStyle(TaskWellTheme.ink)
                                    Text(preset.subtitle(custom: customDate))
                                        .font(.caption)
                                        .foregroundStyle(TaskWellTheme.muted)
                                }
                                Spacer()
                                if selection == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(TaskWellTheme.well)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Snooze until")
                } footer: {
                    Text("Hidden from Suggest until this time. Still visible in the Pool.")
                }

                if selection == .custom || showCustomPicker {
                    Section("Custom") {
                        DatePicker(
                            "Wake at",
                            selection: $customDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .onChange(of: customDate) { _, _ in
                            selection = .custom
                        }
                    }
                }
            }
            .navigationTitle("Snooze until")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSnooze(selection.resolve(custom: customDate))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
