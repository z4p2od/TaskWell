import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PoolTask> { $0.isCompleted },
        sort: [SortDescriptor(\PoolTask.completedAt, order: .reverse)]
    )
    private var completedTasks: [PoolTask]

    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if completedTasks.isEmpty {
                    EmptyStateView(
                        symbolName: "checkmark.seal",
                        title: "No finishes yet",
                        message: "Completed tasks land here. Accept a suggestion or swipe Done in the Pool to start a trail."
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        if let actionError {
                            Section {
                                ErrorBanner(message: actionError) {
                                    self.actionError = nil
                                }
                            }
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(completedTasks, id: \.id) { task in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(task.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(TaskWellTheme.ink)
                                    Text(completedLabel(task))
                                        .font(.caption)
                                        .foregroundStyle(TaskWellTheme.muted)
                                }
                                .padding(.vertical, 2)
                                .swipeActions {
                                    Button {
                                        reopen(task)
                                    } label: {
                                        Label("Reopen", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(TaskWellTheme.well)

                                    Button(role: .destructive) {
                                        delete(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text("\(completedTasks.count) done")
                        } footer: {
                            Text("This history will feed later stats and smarter suggestions.")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .taskWellScreenBackground()
            .navigationTitle("Done")
        }
    }

    private func completedLabel(_ task: PoolTask) -> String {
        if let completedAt = task.completedAt {
            return "Finished \(completedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Finished"
    }

    private func reopen(_ task: PoolTask) {
        task.reopen()
        persist("Couldn’t reopen that task.")
    }

    private func delete(_ task: PoolTask) {
        modelContext.delete(task)
        persist("Couldn’t delete that history item.")
    }

    private func persist(_ errorMessage: String) {
        do {
            try modelContext.save()
            actionError = nil
        } catch {
            actionError = errorMessage
        }
    }
}
