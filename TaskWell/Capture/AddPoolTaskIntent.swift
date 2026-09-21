import AppIntents
import SwiftData

/// Stubbed App Intent surface so Siri / Shortcuts / Action Button can plug in next.
/// Not wired into the running UI yet; kept compile-ready for Phase 2 voice capture.
struct AddPoolTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add TaskWell Task"
    static let description = IntentDescription("Capture a task into the TaskWell pool.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Add a title first.")
        }

        // Intent container is separate from the app UI container for now.
        // When Shortcuts shipping starts, share a single ModelContainer via an app group.
        let schema = Schema([PoolTask.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(PoolTask(title: trimmed))
        try context.save()

        return .result(dialog: "Added “\(trimmed)” to TaskWell.")
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
