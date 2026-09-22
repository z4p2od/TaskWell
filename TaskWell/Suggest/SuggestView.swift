import SwiftUI
import SwiftData

struct SuggestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PoolTask> { !$0.isCompleted },
        sort: [SortDescriptor(\PoolTask.createdAt, order: .reverse)]
    )
    private var openTasks: [PoolTask]

    @State private var selectedMood: SuggestMood?
    @State private var currentTask: PoolTask?
    @State private var showingActiveFocus = false
    /// Session-only exclusions for this Suggest round. Never persisted; cleared on mood change / new pull reset.
    @State private var skippedIDs: Set<UUID> = []
    @State private var actionError: String?
    @State private var isDrawing = false
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showCustomMood = false
    @State private var taskToEdit: PoolTask?
    @State private var taskAwaitingDone: PoolTask?
    @State private var taskAwaitingSnooze: PoolTask?
    @State private var lastCustomDial = CustomSuggestDial.default
    @State private var emptyRoundFromSkips = false

    private let scorer: any TaskSuggesting = LocalTaskScorer()

    private var activeTask: PoolTask? {
        openTasks.first(where: \.isActive)
    }

    private var availableCount: Int {
        openTasks.filter { !$0.isSnoozed && !$0.isActive }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroHeader

                    if let actionError {
                        emptyRoundBanner
                    }

                    if showingActiveFocus, let active = activeTask {
                        SuggestCardView(
                            task: active,
                            moodTitle: selectedMood?.displayTitle,
                            mode: .active,
                            onDone: { complete(active) },
                            onRelease: { release(active) },
                            onEdit: { taskToEdit = active }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        Button("Suggest something else") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showingActiveFocus = false
                                selectedMood = nil
                                currentTask = nil
                                skippedIDs = []
                                emptyRoundFromSkips = false
                                actionError = nil
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaskWellTheme.muted)
                        .frame(maxWidth: .infinity)
                    } else if let selectedMood, let currentTask {
                        SuggestCardView(
                            task: currentTask,
                            moodTitle: selectedMood.displayTitle,
                            mode: .suggestion,
                            onAccept: { accept(currentTask) },
                            onSkip: { skip(currentTask, mood: selectedMood) },
                            onSnooze: { beginSnooze(currentTask) }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        Button("Choose a different mood") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                resetSuggestionOnly()
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaskWellTheme.muted)
                        .frame(maxWidth: .infinity)
                    } else if isDrawing {
                        LoadingStateView(message: "Drawing from the well…")
                            .frame(minHeight: 220)
                    } else {
                        if let active = activeTask {
                            activeBanner(active)
                        }
                        presetGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .taskWellScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(TaskWellTheme.ink.opacity(0.7))
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(TaskWellTheme.coral)
                    }
                    .accessibilityLabel("Quick add")
                }
            }
            .sheet(isPresented: $showAdd) {
                TaskEditorSheet(mode: .create)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $taskToEdit) { task in
                TaskEditorSheet(mode: .edit(task))
            }
            .sheet(item: $taskAwaitingDone) { task in
                DoneConfirmSheet(task: task) { duration, effort, enjoyment in
                    confirmDone(task, duration: duration, effort: effort, enjoyment: enjoyment)
                }
            }
            .sheet(item: $taskAwaitingSnooze) { task in
                SnoozePickerSheet(taskTitle: task.title) { until in
                    applySnooze(task, until: until)
                }
            }
            .sheet(isPresented: $showCustomMood) {
                CustomMoodSheet(initial: lastCustomDial) { dial in
                    lastCustomDial = dial
                    drawSuggestion(mood: .custom(dial))
                }
            }
            .onAppear {
                autoDrawForDemoIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var emptyRoundBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            if emptyRoundFromSkips {
                ErrorBanner(message: actionError ?? "", retry: nil)

                HStack(spacing: 12) {
                    Button {
                        clearSkipsAndRedraw()
                    } label: {
                        Text("Clear skips")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaskWellTheme.well)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            resetSuggestionOnly()
                        }
                    } label: {
                        Text("Change mood")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(TaskWellTheme.wellDeep)
                }
            } else {
                ErrorBanner(message: actionError ?? "") {
                    self.actionError = nil
                    if let selectedMood {
                        drawSuggestion(mood: selectedMood)
                    } else {
                        showCustomMood = true
                    }
                }
            }
        }
    }

    /// Screenshot helpers: `-demoSuggestCard`, `-demoActiveCard`, `-demoCustomMood`, `-demoEditSheet`, `-demoAddSheet`, `-demoSnoozePicker`.
    private func autoDrawForDemoIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoActiveCard") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let active = activeTask {
                    withAnimation {
                        showingActiveFocus = true
                        selectedMood = .preset(.easyWin)
                        currentTask = active
                    }
                } else if let first = openTasks.first(where: { !$0.isSnoozed }) {
                    accept(first)
                }
            }
            return
        }

        if args.contains("-demoEditSheet") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if let first = openTasks.first {
                    taskToEdit = first
                }
            }
            return
        }

        if args.contains("-demoAddSheet") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showAdd = true
            }
            return
        }

        if args.contains("-demoSnoozePicker") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let first = openTasks.first(where: { !$0.isSnoozed && !$0.isActive }) {
                    selectedMood = .preset(.easyWin)
                    currentTask = first
                    taskAwaitingSnooze = first
                }
            }
            return
        }

        if args.contains("-demoCustomMood") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showCustomMood = true
            }
            return
        }

        if args.contains("-demoCustomCard") {
            guard selectedMood == nil, !showingActiveFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                let dial = CustomSuggestDial(minutesAvailable: 25, appetite: 0.3)
                lastCustomDial = dial
                drawSuggestion(mood: .custom(dial))
            }
            return
        }

        guard args.contains("-demoSuggestCard") else { return }
        guard selectedMood == nil, !showingActiveFocus else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            drawSuggestion(mood: .preset(.easyWin))
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TaskWell")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(heroCopy)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Text(availableCount == 1 ? "1 task ready" : "\(availableCount) tasks ready")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.18), in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskWellTheme.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: TaskWellTheme.wellDeep.opacity(0.25), radius: 20, y: 10)
    }

    private var heroCopy: String {
        if showingActiveFocus {
            return "Accepted means you’re on it. Tap Done only when the work is finished."
        }
        if selectedMood != nil {
            return "Accept to start this one — it stays open until you mark it Done."
        }
        return "Tell the well how much time or energy you have. It pulls one task."
    }

    private func activeBanner(_ task: PoolTask) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                showingActiveFocus = true
                selectedMood = selectedMood ?? .preset(.easyWin)
                currentTask = task
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .foregroundStyle(TaskWellTheme.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("In progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaskWellTheme.coral)
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaskWellTheme.ink)
                        .lineLimit(2)
                }
                Spacer()
                Text("Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.well)
            }
            .padding(14)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(TaskWellTheme.coral.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How are you right now?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(TaskWellTheme.ink)

            if openTasks.isEmpty {
                EmptyStateView(
                    symbolName: "drop.fill",
                    title: "Nothing in the well yet",
                    message: "Add a few tasks to the pool first. Suggest needs something to draw from.",
                    actionTitle: "Quick add"
                ) {
                    showAdd = true
                }
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if availableCount == 0 && activeTask == nil {
                EmptyStateView(
                    symbolName: "moon.zzz.fill",
                    title: "Everything is snoozed",
                    message: "All open tasks are resting. Come back later, or unsnooze from the Pool."
                )
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if availableCount == 0, activeTask != nil {
                EmptyStateView(
                    symbolName: "flag.fill",
                    title: "You’re already on one",
                    message: "Finish or put back your in-progress task before drawing another suggestion."
                )
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(SuggestPreset.allCases) { preset in
                        moodTile(
                            title: preset.title,
                            subtitle: preset.subtitle,
                            symbol: preset.symbolName
                        ) {
                            drawSuggestion(mood: .preset(preset))
                        }
                    }

                    moodTile(
                        title: "Custom…",
                        subtitle: "Set your time and appetite",
                        symbol: "slider.horizontal.3"
                    ) {
                        showCustomMood = true
                    }
                }
            }
        }
    }

    private func moodTile(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.well)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(TaskWellTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(TaskWellTheme.well.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func drawSuggestion(mood: SuggestMood) {
        actionError = nil
        emptyRoundFromSkips = false
        isDrawing = true
        selectedMood = mood
        showingActiveFocus = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let next = scorer.suggest(
                from: openTasks,
                mood: mood,
                excluding: skippedIDs,
                now: Date()
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                currentTask = next
                isDrawing = false
                if next == nil {
                    emptyRoundFromSkips = !skippedIDs.isEmpty
                    actionError = emptyFitMessage(for: mood)
                }
            }
        }
    }

    private func emptyFitMessage(for mood: SuggestMood) -> String {
        if !skippedIDs.isEmpty {
            return "You’ve seen everything that fits this mood. Change mood or clear skips."
        }
        if case .custom = mood {
            return "Nothing in the pool fits that time and appetite. Loosen a dial, or add a task that matches."
        }
        return "No open tasks fit that mood right now. Try another preset or add to the pool."
    }

    private func clearSkipsAndRedraw() {
        guard let mood = selectedMood else {
            skippedIDs = []
            emptyRoundFromSkips = false
            actionError = nil
            return
        }
        skippedIDs = []
        emptyRoundFromSkips = false
        drawSuggestion(mood: mood)
    }

    private func accept(_ task: PoolTask) {
        for other in openTasks where other.isActive && other.id != task.id {
            other.clearActive()
        }
        task.markAccepted()
        persist("Couldn’t accept that task. Try again.") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                currentTask = task
                showingActiveFocus = true
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
        persist("Couldn’t mark that task Done. Try again.") {
            withAnimation {
                resetFlow()
            }
        }
    }

    private func release(_ task: PoolTask) {
        task.clearActive()
        persist("Couldn’t put that task back. Try again.") {
            withAnimation {
                showingActiveFocus = false
                currentTask = nil
                selectedMood = nil
                skippedIDs = []
            }
        }
    }

    /// Skip = this Suggest session only. Never writes snooze or other persisted state.
    private func skip(_ task: PoolTask, mood: SuggestMood) {
        skippedIDs.insert(task.id)
        drawSuggestion(mood: mood)
    }

    private func beginSnooze(_ task: PoolTask) {
        taskAwaitingSnooze = task
    }

    /// Snooze sets `snoozedUntil` only — does not touch `skippedIDs`.
    private func applySnooze(_ task: PoolTask, until: Date) {
        task.snooze(until: until)
        persist("Couldn’t snooze that task. Try again.") {
            if let mood = selectedMood {
                drawSuggestion(mood: mood)
            } else {
                currentTask = nil
            }
        }
    }

    private func resetSuggestionOnly() {
        selectedMood = nil
        currentTask = nil
        skippedIDs = []
        actionError = nil
        emptyRoundFromSkips = false
        isDrawing = false
        showingActiveFocus = false
    }

    private func resetFlow() {
        resetSuggestionOnly()
    }

    private func persist(_ errorMessage: String, success: () -> Void) {
        do {
            try modelContext.save()
            actionError = nil
            success()
        } catch {
            actionError = errorMessage
        }
    }
}
