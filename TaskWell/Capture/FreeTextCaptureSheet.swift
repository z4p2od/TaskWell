import SwiftUI
import SwiftData

/// Reserved for future **voice → task** entry (Siri / App Intent / Action Button).
/// Not presented from the normal + path anymore — structured `TaskEditorSheet` is primary.
/// Keep parse + enrichment wired so voice can land pre-filled fields without a “Looks like” UI.
struct FreeTextCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<PoolTask> { $0.isCompleted },
        sort: [SortDescriptor(\PoolTask.completedAt, order: .reverse)]
    )
    private var completedTasks: [PoolTask]

    @State private var blob = ""
    @State private var draft = ParsedTaskDraft()
    @State private var showAdvanced = false
    @State private var saveError: String?
    @State private var similarityNote: String?
    @State private var isEnriching = false
    @State private var parseTask: Task<Void, Never>?

    @FocusState private var blobFocused: Bool

    private let parser: any TaskCaptureParsing = NativeTaskCaptureParser()
    private let enricher: any TaskEnriching = CompositeTaskEnricher()
    private let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Dump it in the well")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(TaskWellTheme.ink)

                    Text("Type or paste freely — “buy milk tomorrow, ~15 min, I dread this.” TaskWell reads what it can on-device.")
                        .font(.subheadline)
                        .foregroundStyle(TaskWellTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $blob)
                        .font(.body)
                        .focused($blobFocused)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(TaskWellTheme.well.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: blob) { _, _ in
                            scheduleParse()
                        }

                    if draft.hasTitle || draft.dueDate != nil || draft.durationMinutes != nil
                        || draft.effort != nil || draft.enjoyment != nil {
                        previewSection
                    }

                    if let similarityNote {
                        Text(similarityNote)
                            .font(.caption)
                            .foregroundStyle(TaskWellTheme.muted)
                    }

                    if isEnriching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(
                                EnrichmentSettings.canUseAI
                                    ? "Enriching with AI…"
                                    : "Suggesting from history…"
                            )
                            .font(.caption)
                            .foregroundStyle(TaskWellTheme.muted)
                        }
                    }

                    DisclosureGroup("More options", isExpanded: $showAdvanced) {
                        advancedEditors
                            .padding(.top, 8)
                    }
                    .tint(TaskWellTheme.well)

                    if let saveError {
                        ErrorBanner(message: saveError) {
                            self.saveError = nil
                            save()
                        }
                    }

                    Button {
                        save()
                    } label: {
                        Label("Add to pool", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaskWellTheme.well)
                    .controlSize(.large)
                    .disabled(!draft.hasTitle)
                }
                .padding(20)
            }
            .taskWellScreenBackground()
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-demoFreeText") {
                    blob = "buy milk tomorrow, ~15 min, I dread this"
                    Task { @MainActor in
                        await applyParseAndEnrich()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    blobFocused = true
                }
            }
            .onDisappear {
                parseTask?.cancel()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Looks like")
                .font(.headline)
                .foregroundStyle(TaskWellTheme.ink)

            TextField("Title", text: Binding(
                get: { draft.title },
                set: {
                    draft.title = $0
                    draft.titleSource = .manual
                    scheduleEnrichOnly()
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.body.weight(.medium))

            FlowChipRow {
                chip(
                    label: draft.dueDate.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Due",
                    symbol: "calendar",
                    filled: draft.dueDate != nil,
                    source: draft.dueSource
                ) {
                    // Cycle: clear ↔ tomorrow morning for quick tweak; advanced has full picker.
                    if draft.dueDate == nil {
                        let cal = Calendar.current
                        let next = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        draft.dueDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: next)
                        draft.dueSource = .manual
                    } else {
                        draft.dueDate = nil
                        draft.dueSource = .unset
                    }
                }

                chip(
                    label: draft.durationMinutes.map { "\($0) min" } ?? "Duration",
                    symbol: "clock",
                    filled: draft.durationMinutes != nil,
                    source: draft.durationSource
                ) {
                    cycleDuration()
                }

                chip(
                    label: draft.effort?.title ?? "Effort",
                    symbol: draft.effort?.symbolName ?? "bolt",
                    filled: draft.effort != nil,
                    source: draft.effortSource
                ) {
                    cycleEffort()
                }

                chip(
                    label: draft.enjoyment?.title ?? "Enjoyment",
                    symbol: draft.enjoyment?.symbolName ?? "cloud",
                    filled: draft.enjoyment != nil,
                    source: draft.enjoymentSource
                ) {
                    cycleEnjoyment()
                }
            }

            Text("Tap a chip to cycle. Open More options for exact values.")
                .font(.caption)
                .foregroundStyle(TaskWellTheme.muted)
        }
        .padding(14)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var advancedEditors: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Due date", isOn: Binding(
                get: { draft.dueDate != nil },
                set: { on in
                    if on {
                        draft.dueDate = draft.dueDate ?? Date()
                        draft.dueSource = .manual
                    } else {
                        draft.dueDate = nil
                        draft.dueSource = .unset
                    }
                }
            ))
            if draft.dueDate != nil {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { draft.dueDate ?? Date() },
                        set: {
                            draft.dueDate = $0
                            draft.dueSource = .manual
                        }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Picker("Effort", selection: Binding(
                get: { draft.effort },
                set: {
                    draft.effort = $0
                    draft.effortSource = $0 == nil ? .unset : .manual
                }
            )) {
                Text("Not set").tag(Optional<EffortLevel>.none)
                ForEach(EffortLevel.allCases) { level in
                    Text(level.title).tag(Optional(level))
                }
            }

            Picker("Enjoyment", selection: Binding(
                get: { draft.enjoyment },
                set: {
                    draft.enjoyment = $0
                    draft.enjoymentSource = $0 == nil ? .unset : .manual
                }
            )) {
                Text("Not set").tag(Optional<EnjoymentLevel>.none)
                ForEach(EnjoymentLevel.allCases) { level in
                    Text(level.title).tag(Optional(level))
                }
            }

            Picker("Duration", selection: Binding(
                get: { draft.durationMinutes },
                set: {
                    draft.durationMinutes = $0
                    draft.durationSource = $0 == nil ? .unset : .manual
                }
            )) {
                Text("Not set").tag(Optional<Int>.none)
                ForEach(durationChoices, id: \.self) { minutes in
                    Text("\(minutes) min").tag(Optional(minutes))
                }
            }
        }
    }

    private func chip(
        label: String,
        symbol: String,
        filled: Bool,
        source: ParsedTaskDraft.FieldSource,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    filled ? TaskWellTheme.mist : TaskWellTheme.sand.opacity(0.7),
                    in: Capsule()
                )
                .foregroundStyle(filled ? TaskWellTheme.wellDeep : TaskWellTheme.muted)
                .overlay(
                    Capsule()
                        .strokeBorder(chipBorder(source), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func chipBorder(_ source: ParsedTaskDraft.FieldSource) -> Color {
        switch source {
        case .similar, .enriched: return TaskWellTheme.coral.opacity(0.5)
        case .ai: return TaskWellTheme.well.opacity(0.55)
        default: return .clear
        }
    }

    private func scheduleParse() {
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await applyParseAndEnrich()
        }
    }

    private func scheduleEnrichOnly() {
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await enrichCurrentDraft(preservingManual: true)
        }
    }

    private func applyParseAndEnrich() async {
        var parsed = parser.parse(blob, now: Date())
        // Preserve manual chip overrides where user already tweaked.
        if draft.titleSource == .manual { parsed.title = draft.title; parsed.titleSource = .manual }
        if draft.dueSource == .manual { parsed.dueDate = draft.dueDate; parsed.dueSource = .manual }
        if draft.durationSource == .manual { parsed.durationMinutes = draft.durationMinutes; parsed.durationSource = .manual }
        if draft.effortSource == .manual { parsed.effort = draft.effort; parsed.effortSource = .manual }
        if draft.enjoymentSource == .manual { parsed.enjoyment = draft.enjoyment; parsed.enjoymentSource = .manual }
        draft = parsed
        await enrichCurrentDraft(preservingManual: true)
    }

    private func enrichCurrentDraft(preservingManual: Bool) async {
        guard draft.hasTitle else {
            similarityNote = nil
            return
        }
        isEnriching = true
        defer { isEnriching = false }

        let before = draft
        let enriched = await enricher.enrich(draft, completed: completedTasks)
        guard !Task.isCancelled else { return }

        var next = enriched
        if preservingManual {
            if before.dueSource == .manual { next.dueDate = before.dueDate; next.dueSource = .manual }
            if before.durationSource == .manual { next.durationMinutes = before.durationMinutes; next.durationSource = .manual }
            if before.effortSource == .manual { next.effort = before.effort; next.effortSource = .manual }
            if before.enjoymentSource == .manual { next.enjoyment = before.enjoyment; next.enjoymentSource = .manual }
            if before.titleSource == .manual { next.title = before.title; next.titleSource = .manual }
        }
        draft = next
        similarityNote = enrichmentNote(before: before, after: next)
    }

    private func enrichmentNote(before: ParsedTaskDraft, after: ParsedTaskDraft) -> String? {
        var bits: [String] = []
        if before.durationMinutes == nil, after.durationMinutes != nil {
            bits.append("\(after.durationMinutes!) min")
        }
        if before.effort == nil, let effort = after.effort { bits.append(effort.title) }
        if before.enjoyment == nil, let enjoyment = after.enjoyment { bits.append(enjoyment.title) }
        guard !bits.isEmpty else { return nil }

        let sources = [after.durationSource, after.effortSource, after.enjoymentSource]
        if sources.contains(.ai) {
            return "AI suggested \(bits.joined(separator: ", ")) — tweak chips before saving."
        }
        if sources.contains(.similar) {
            return "Filled \(bits.joined(separator: ", ")) from similar Done history."
        }
        if sources.contains(.enriched) {
            return "Suggested \(bits.joined(separator: ", ")) from the title."
        }
        return "Suggested \(bits.joined(separator: ", "))."
    }

    private func cycleDuration() {
        let options: [Int?] = [nil] + durationChoices.map(Optional.init)
        let current = draft.durationMinutes
        let idx = options.firstIndex(of: current) ?? 0
        let next = options[(idx + 1) % options.count]
        draft.durationMinutes = next
        draft.durationSource = next == nil ? .unset : .manual
    }

    private func cycleEffort() {
        let options: [EffortLevel?] = [nil] + EffortLevel.allCases.map(Optional.init)
        let idx = options.firstIndex(of: draft.effort) ?? 0
        let next = options[(idx + 1) % options.count]
        draft.effort = next
        draft.effortSource = next == nil ? .unset : .manual
    }

    private func cycleEnjoyment() {
        let options: [EnjoymentLevel?] = [nil] + EnjoymentLevel.allCases.map(Optional.init)
        let idx = options.firstIndex(of: draft.enjoyment) ?? 0
        let next = options[(idx + 1) % options.count]
        draft.enjoyment = next
        draft.enjoymentSource = next == nil ? .unset : .manual
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            saveError = "Add a title (or a sentence the well can read as one)."
            return
        }
        let task = PoolTask(
            title: title,
            dueDate: draft.dueDate,
            effort: draft.effort,
            enjoyment: draft.enjoyment,
            durationMinutes: draft.durationMinutes,
            rawCaptureText: blob.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            modelContext.insert(task)
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Couldn’t save that task. Try again."
        }
    }
}

/// Simple wrapping chip layout without an extra dependency.
private struct FlowChipRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        // LazyVGrid keeps chips tidy without a custom flow layout.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
    }
}
