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
    @State private var selectedTab = 0
    @State private var showAdd = false

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
                .safeAreaInset(edge: .bottom) {
                    // Floating quick-add affordance sits above the tab bar on Suggest.
                    if selectedTab == 0 {
                        HStack {
                            Spacer()
                            Button {
                                showAdd = true
                            } label: {
                                Label("Quick add", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(TaskWellTheme.coral, in: Capsule())
                                    .foregroundStyle(.white)
                                    .shadow(color: TaskWellTheme.coral.opacity(0.35), radius: 10, y: 4)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .sheet(isPresented: $showAdd) {
                    QuickAddSheet()
                }
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
        .onAppear { probeStore() }
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
}
