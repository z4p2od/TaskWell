import SwiftUI
import SwiftData

struct SuggestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PoolTask> { !$0.isCompleted },
        sort: [SortDescriptor(\PoolTask.createdAt, order: .reverse)]
    )
    private var openTasks: [PoolTask]

    @State private var selectedPreset: SuggestPreset?
    @State private var currentTask: PoolTask?
    @State private var skippedIDs: Set<UUID> = []
    @State private var actionError: String?
    @State private var isDrawing = false
    @State private var showAdd = false

    private let scorer: any TaskSuggesting = LocalTaskScorer()

    private var availableCount: Int {
        openTasks.filter { !$0.isSnoozed }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroHeader

                    if let actionError {
                        ErrorBanner(message: actionError) {
                            self.actionError = nil
                            if let selectedPreset {
                                drawSuggestion(for: selectedPreset)
                            }
                        }
                    }

                    if let selectedPreset, let currentTask {
                        SuggestCardView(
                            task: currentTask,
                            preset: selectedPreset,
                            onAccept: { accept(currentTask) },
                            onSkip: { skip(currentTask, preset: selectedPreset) },
                            onSnooze: { snooze(currentTask, preset: selectedPreset) }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        Button("Choose a different mood") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                resetFlow()
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaskWellTheme.muted)
                        .frame(maxWidth: .infinity)
                    } else if isDrawing {
                        LoadingStateView(message: "Drawing from the well…")
                            .frame(minHeight: 220)
                    } else {
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
                QuickAddSheet()
            }
            .onAppear {
                autoDrawForDemoIfNeeded()
            }
        }
    }

    /// Screenshot helper: `-demoSuggestCard` draws an Easy win card after seed.
    private func autoDrawForDemoIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-demoSuggestCard") else { return }
        guard selectedPreset == nil else { return }
        // Wait a beat so seeded @Query results are visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            drawSuggestion(for: .easyWin)
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TaskWell")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(
                selectedPreset == nil
                    ? "Tell the well how much time or energy you have. It pulls one task."
                    : "One card. Accept it, skip for another, or snooze it for later."
            )
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
            } else if availableCount == 0 {
                EmptyStateView(
                    symbolName: "moon.zzz.fill",
                    title: "Everything is snoozed",
                    message: "All open tasks are resting. Come back later, or unsnooze from the Pool."
                )
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(SuggestPreset.allCases) { preset in
                        Button {
                            drawSuggestion(for: preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: preset.symbolName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(TaskWellTheme.well)
                                Text(preset.title)
                                    .font(.headline)
                                    .foregroundStyle(TaskWellTheme.ink)
                                Text(preset.subtitle)
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
                }
            }
        }
    }

    private func drawSuggestion(for preset: SuggestPreset) {
        actionError = nil
        isDrawing = true
        selectedPreset = preset

        // Brief pause so the loading state is visible and the card transition feels intentional.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let next = scorer.suggest(
                from: openTasks,
                preset: preset,
                excluding: skippedIDs,
                now: Date()
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                currentTask = next
                isDrawing = false
                if next == nil {
                    actionError = skippedIDs.isEmpty
                        ? "No open tasks fit that mood right now. Try another preset or add to the pool."
                        : "You’ve skipped through the matching tasks. Reset or pick a different mood."
                }
            }
        }
    }

    private func accept(_ task: PoolTask) {
        task.markCompleted()
        persist("Couldn’t complete that task. Try again.") {
            withAnimation {
                resetFlow()
            }
        }
    }

    private func skip(_ task: PoolTask, preset: SuggestPreset) {
        skippedIDs.insert(task.id)
        drawSuggestion(for: preset)
    }

    private func snooze(_ task: PoolTask, preset: SuggestPreset) {
        let later = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(4 * 3600)
        task.snooze(until: later)
        skippedIDs.insert(task.id)
        persist("Couldn’t snooze that task. Try again.") {
            drawSuggestion(for: preset)
        }
    }

    private func resetFlow() {
        selectedPreset = nil
        currentTask = nil
        skippedIDs = []
        actionError = nil
        isDrawing = false
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
