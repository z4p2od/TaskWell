import SwiftUI

/// Sheet to set time available + appetite, then pull one card.
struct CustomMoodSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double
    @State private var appetite: Double

    var onPull: (CustomSuggestDial) -> Void

    init(
        initial: CustomSuggestDial = .default,
        onPull: @escaping (CustomSuggestDial) -> Void
    ) {
        _minutes = State(initialValue: Double(initial.minutesAvailable))
        _appetite = State(initialValue: initial.appetite)
        self.onPull = onPull
    }

    private var dial: CustomSuggestDial {
        CustomSuggestDial(minutesAvailable: Int(minutes.rounded()), appetite: appetite)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dial in this moment")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(TaskWellTheme.ink)
                        Text("Set how much time you have and how much hard work you’ll stomach. Then pull one task.")
                            .font(.body)
                            .foregroundStyle(TaskWellTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    timeSection
                    appetiteSection

                    Button {
                        let chosen = dial
                        dismiss()
                        // Dismiss first so the sheet doesn’t cover the card transition.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onPull(chosen)
                        }
                    } label: {
                        Label("Pull a task", systemImage: "drop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaskWellTheme.well)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .taskWellScreenBackground()
            .navigationTitle("Custom mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Time available")
                    .font(.headline)
                    .foregroundStyle(TaskWellTheme.ink)
                Spacer()
                Text(minutesLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.wellDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(TaskWellTheme.mist, in: Capsule())
            }

            Slider(
                value: $minutes,
                in: Double(CustomSuggestDial.minutesRange.lowerBound)...Double(CustomSuggestDial.minutesRange.upperBound),
                step: 5
            )
            .tint(TaskWellTheme.well)

            HStack {
                Button {
                    minutes = max(Double(CustomSuggestDial.minutesRange.lowerBound), minutes - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(TaskWellTheme.well)
                }
                .accessibilityLabel("Five minutes less")

                Spacer()

                Text("5 min")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
                Text("—")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
                Text("3 hr")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)

                Spacer()

                Button {
                    minutes = min(Double(CustomSuggestDial.minutesRange.upperBound), minutes + 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(TaskWellTheme.well)
                }
                .accessibilityLabel("Five minutes more")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var appetiteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appetite")
                .font(.headline)
                .foregroundStyle(TaskWellTheme.ink)

            Text(dial.appetiteLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaskWellTheme.wellDeep)
                .fixedSize(horizontal: false, vertical: true)

            Slider(value: $appetite, in: 0...1)
                .tint(TaskWellTheme.coral)

            HStack {
                Label("Go easy on me", systemImage: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
                Spacer()
                Label("I’ll take a dread", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
            }

            Text("Low appetite prefers Enjoy and Quick tasks. High appetite is willing to surface Dread.")
                .font(.caption)
                .foregroundStyle(TaskWellTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var minutesLabel: String {
        let value = Int(minutes.rounded())
        if value < 60 { return "\(value) min" }
        let hours = value / 60
        let rem = value % 60
        return rem == 0 ? "\(hours) hr" : "\(hours) hr \(rem) min"
    }
}
