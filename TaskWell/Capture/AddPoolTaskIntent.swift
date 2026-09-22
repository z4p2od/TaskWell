import AppIntents
import SwiftData

/// Voice / Shortcuts entry: parse transcript off-screen, save a pool task.
/// UI path remains structured `TaskEditorSheet`; this Intent is the future voice handoff.
struct AddPoolTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add TaskWell Task"
    static let description = IntentDescription("Capture a task into the TaskWell pool from a short phrase or voice transcript.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Title or phrase")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Add a title first.")
        }

        let parser: any TaskCaptureParsing = NativeTaskCaptureParser()
        let draft = parser.parse(trimmed, now: Date())
        let resolvedTitle = draft.hasTitle
            ? draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed

        // Intent container is separate from the app UI container for now.
        // When Shortcuts shipping starts, share a single ModelContainer via an app group.
        let schema = Schema([PoolTask.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(
            PoolTask(
                title: resolvedTitle,
                dueDate: draft.dueDate,
                effort: draft.effort,
                enjoyment: draft.enjoyment,
                durationMinutes: draft.durationMinutes,
                rawCaptureText: trimmed
            )
        )
        try context.save()

        return .result(dialog: "Added “\(resolvedTitle)” to TaskWell.")
    }
}

struct TaskWellAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPoolTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Capture a task with \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
