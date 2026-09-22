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

    @State private var filters: TaskPoolFilters = {
        var value = TaskPoolFilters()
        if ProcessInfo.processInfo.arguments.contains("-demoFilterSnoozed") {
            value.status = .snoozed
        }
        return value
    }()
    @State private var showAdd = false
    @State private var taskToEdit: PoolTask?
    @State private var taskAwaitingDone: PoolTask?
    @State private var actionError: String?

    private var filteredTasks: [PoolTask] {
        openTasks.filter { filters.matches($0) }
    }

    /// Available + in-progress (not snoozed), in-progress first.
    private var primaryTasks: [PoolTask] {
        filteredTasks
            .filter { !$0.isSnoozed }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
                return false
            }
    }

    private var snoozedTasks: [PoolTask] {
        filteredTasks
            .filter(\.isSnoozed)
            .sorted { ($0.snoozedUntil ?? .distantFuture) < ($1.snoozedUntil ?? .distantFuture) }
    }

    /// Show a dedicated Snoozed section only when snoozed rows exist and we aren't already filtering to Snoozed-only.
    private var showsSnoozedSection: Bool {
        !snoozedTasks.isEmpty && !filters.isSnoozedOnly
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

                        if filters.isSnoozedOnly {
                            Section {
                                ForEach(snoozedTasks, id: \.id) { task in
                                    poolRow(task, showInlineUnsnooze: true)
                                }
                            } header: {
                                Text("\(snoozedTasks.count) snoozed")
                            } footer: {
                                Text("Tap to edit. Swipe Unsnooze or Done.")
                            }
                        } else {
                            if !primaryTasks.isEmpty {
                                Section {
                                    ForEach(primaryTasks, id: \.id) { task in
                                        poolRow(task, showInlineUnsnooze: false)
                                    }
                                } header: {
                                    Text("\(primaryTasks.count) open")
                                } footer: {
                                    if !showsSnoozedSection {
                                        Text("Tap a task to edit. Swipe Done or Delete.")
                                    }
                                }
                            }

                            if showsSnoozedSection {
                                Section {
                                    ForEach(snoozedTasks, id: \.id) { task in
                                        poolRow(task, showInlineUnsnooze: true)
                                    }
                                } header: {
                                    Text("Snoozed")
                                } footer: {
                                    Text("Hidden from Suggest until their wake time. Tap Unsnooze to bring one back.")
                                }
                            }
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
                        Section("Status") {
                            ForEach(PoolStatusFilter.allCases) { status in
                                Button(status.title) { filters.status = status }
                            }
                        }
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
                TaskEditorSheet(mode: .create)
            }
            .sheet(item: $taskToEdit) { task in
                TaskEditorSheet(mode: .edit(task))
            }
            .sheet(item: $taskAwaitingDone) { task in
                DoneConfirmSheet(task: task) { duration, effort, enjoyment in
                    confirmDone(task, duration: duration, effort: effort, enjoyment: enjoyment)
                }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-demoEditSheet") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        if taskToEdit == nil, let first = openTasks.first {
                            taskToEdit = first
                        }
                    }
                }
                if args.contains("-demoDoneConfirm") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if taskAwaitingDone == nil, let first = openTasks.first {
                            taskAwaitingDone = first
                        }
                    }
                }
                if args.contains("-demoAddSheet") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showAdd = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func poolRow(_ task: PoolTask, showInlineUnsnooze: Bool) -> some View {
        Button {
            taskToEdit = task
        } label: {
            TaskRowView(
                task: task,
                showsUnsnoozeButton: showInlineUnsnooze,
                onUnsnooze: { unsnooze(task) }
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                taskToEdit = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(TaskWellTheme.wellDeep)
            if task.isSnoozed {
                Button {
                    unsnooze(task)
                } label: {
                    Label("Unsnooze", systemImage: "sun.max.fill")
                }
                .tint(TaskWellTheme.coral)
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
        .contextMenu {
            Button {
                taskToEdit = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            if task.isSnoozed {
                Button {
                    unsnooze(task)
                } label: {
                    Label("Unsnooze", systemImage: "sun.max.fill")
                }
            }
            Button {
                complete(task)
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func complete(_ task: PoolTask) {
        taskAwaitingDone = task
    }

    private func confirmDone(
        _ task: PoolTask,
        duration: Int?,
        effort: EffortLevel?,
        enjoyment: EnjoymentLevel?
    ) {
        task.markCompleted(
            actualDurationMinutes: duration,
            actualEffort: effort,
            actualEnjoyment: enjoyment
        )
        persist("Couldn’t mark that task done. Try again.")
    }

    private func unsnooze(_ task: PoolTask) {
        task.unsnooze()
        persist("Couldn’t unsnooze that task. Try again.")
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
