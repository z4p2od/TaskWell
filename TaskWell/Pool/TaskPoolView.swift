import SwiftUI
import SwiftData

struct TaskPoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PoolTask> { !$0.isCompleted },
        sort: [
            SortDescriptor(\PoolTask.dueDate, order: .forward),
            SortDescriptor(\PoolTask.createdAt, order: .reverse)
        ]
    )
    private var openTasks: [PoolTask]

    @State private var filters = TaskPoolFilters()
    @State private var showAdd = false
    @State private var actionError: String?

    private var filteredTasks: [PoolTask] {
        openTasks
            .filter { filters.matches($0) }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
                return false
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if openTasks.isEmpty {
                    EmptyStateView(
                        symbolName: "tray",
                        title: "Your pool is empty",
                        message: "Drop a task in the well. When you have time, Suggest will fish one out for you.",
                        actionTitle: "Add a task"
                    ) {
                        showAdd = true
                    }
                    .frame(maxHeight: .infinity)
                } else if filteredTasks.isEmpty {
                    EmptyStateView(
                        symbolName: "line.3.horizontal.decrease.circle",
                        title: "Nothing matches",
                        message: "No open tasks fit these filters. Clear them or add something new.",
                        actionTitle: "Clear filters"
                    ) {
                        filters.clear()
                    }
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
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }

                        Section {
                            ForEach(filteredTasks, id: \.id) { task in
                                TaskRowView(task: task)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            complete(task)
                                        } label: {
                                            Label("Done", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(TaskWellTheme.well)
                                    }
                            }
                        } header: {
                            Text("\(filteredTasks.count) open")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .taskWellScreenBackground()
            .navigationTitle("Pool")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Effort") {
                            Button("Any effort") { filters.effort = nil }
                            ForEach(EffortLevel.allCases) { level in
                                Button {
                                    filters.effort = level
                                } label: {
                                    Label(level.title, systemImage: level.symbolName)
                                }
                            }
                        }
                        Section("Enjoyment") {
                            Button("Any enjoyment") { filters.enjoyment = nil }
                            ForEach(EnjoymentLevel.allCases) { level in
                                Button {
                                    filters.enjoyment = level
                                } label: {
                                    Label(level.title, systemImage: level.symbolName)
                                }
                            }
                        }
                        Section("Due") {
                            ForEach(DueFilter.allCases) { due in
                                Button(due.title) { filters.due = due }
                            }
                        }
                        if filters.isActive {
                            Divider()
                            Button("Clear filters", role: .destructive) {
                                filters.clear()
                            }
                        }
                    } label: {
                        Label(
                            "Filter",
                            systemImage: filters.isActive
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(TaskWellTheme.well)
                    }
                    .accessibilityLabel("Add task")
                }
            }
            .sheet(isPresented: $showAdd) {
                QuickAddSheet()
            }
        }
    }

    private func complete(_ task: PoolTask) {
        task.markCompleted()
        persist("Couldn’t mark that task done. Try again.")
    }

    private func delete(_ task: PoolTask) {
        modelContext.delete(task)
        persist("Couldn’t delete that task. Try again.")
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
