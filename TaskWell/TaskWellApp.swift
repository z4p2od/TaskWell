import SwiftUI
import SwiftData

@main
struct TaskWellApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PoolTask.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
            // CloudKit sync intentionally off for MVP. Enable later with
            // cloudKitDatabase: .automatic once the Apple Developer team is set.
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to in-memory so the UI can still show an error state.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var storeHealthy = true
    @State private var selectedTab = RootView.initialTab()

    var body: some View {
        Group {
            if storeHealthy {
                TabView(selection: $selectedTab) {
                    SuggestView()
                        .tabItem {
                            Label("Suggest", systemImage: "drop.fill")
                        }
                        .tag(0)

                    TaskPoolView()
                        .tabItem {
                            Label("Pool", systemImage: "rectangle.stack.fill")
                        }
                        .tag(1)

                    HistoryView()
                        .tabItem {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tag(2)
                }
                .tint(TaskWellTheme.well)
            } else {
                VStack {
                    EmptyStateView(
                        symbolName: "externaldrive.badge.exclamationmark",
                        title: "Storage couldn’t open",
                        message: "TaskWell couldn’t reach local storage. Restart the app. If this keeps happening, delete and reinstall the Simulator build.",
                        actionTitle: "Retry"
                    ) {
                        probeStore()
                    }
                }
                .taskWellScreenBackground()
            }
        }
        .onAppear {
            probeStore()
            seedDemoDataIfRequested()
        }
    }

    /// Screenshot helper: `-demoTab pool|done|suggest` (default suggest).
    private static func initialTab() -> Int {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-demoTab"), args.indices.contains(index + 1) {
            switch args[index + 1].lowercased() {
            case "pool": return 1
            case "done", "history": return 2
            default: return 0
            }
        }
        return 0
    }

    private func probeStore() {
        // Lightweight write probe so first launch surfaces storage problems clearly.
        do {
            try modelContext.save()
            storeHealthy = true
        } catch {
            storeHealthy = false
        }
    }

    /// Simulator / screenshot helper: launch with `-seedDemoData` to preload sample tasks.
    private func seedDemoDataIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemoData") else { return }

        let existing = try? modelContext.fetch(FetchDescriptor<PoolTask>())
        guard existing?.isEmpty != false else { return }

        let cal = Calendar.current
        let samples: [(String, EffortLevel?, EnjoymentLevel?, Int?, Date?)] = [
            ("Reply to Maya about Friday dinner", .quick, .enjoy, 10, cal.date(byAdding: .hour, value: 5, to: Date())),
            ("Clear the kitchen counter", .quick, .meh, 15, nil),
            ("Draft Q3 budget notes", .medium, .dread, 30, cal.date(byAdding: .day, value: 1, to: Date())),
            ("Walk around the block", .quick, .enjoy, 20, nil),
            ("File last month’s receipts", .big, .dread, 60, cal.date(byAdding: .day, value: -1, to: Date())),
            ("Read two chapters of the novel", .medium, .enjoy, 35, cal.date(byAdding: .day, value: 3, to: Date()))
        ]

        for sample in samples {
            modelContext.insert(
                PoolTask(
                    title: sample.0,
                    dueDate: sample.4,
                    effort: sample.1,
                    enjoyment: sample.2,
                    durationMinutes: sample.3
                )
            )
        }

        // One completed item so Done isn’t empty in demos.
        let done = PoolTask(title: "Water the plants", effort: .quick, enjoyment: .enjoy, durationMinutes: 5)
        done.markCompleted(at: Date().addingTimeInterval(-3600))
        modelContext.insert(done)

        try? modelContext.save()
    }
}
