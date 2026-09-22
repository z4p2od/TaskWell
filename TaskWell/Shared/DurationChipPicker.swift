import SwiftUI

/// Duration chip values for the approved compact picker.
/// - `twoHoursPlus` stores **120** minutes; UI label is **2h+** (open-ended feel in copy).
enum DurationChip: Equatable, Hashable {
    case ten
    case thirty
    case oneHour
    case twoHoursPlus
    case custom(Int)

    /// Stored minutes for chip presets. `2h+` → 120.
    var minutes: Int {
        switch self {
        case .ten: 10
        case .thirty: 30
        case .oneHour: 60
        case .twoHoursPlus: 120
        case .custom(let value): value
        }
    }

    var label: String {
        switch self {
        case .ten: "10m"
        case .thirty: "30m"
        case .oneHour: "1h"
        case .twoHoursPlus: "2h+"
        case .custom(let value): DurationFormatting.label(minutes: value)
        }
    }

    static func matching(_ minutes: Int?) -> DurationChip? {
        guard let minutes else { return nil }
        switch minutes {
        case 10: return .ten
        case 30: return .thirty
        case 60: return .oneHour
        case 120: return .twoHoursPlus
        default: return .custom(minutes)
        }
    }
}

enum DurationFormatting {
    static let customRange = 5...480 // 5 min – 8 hr
    static let customStep = 5

    static func label(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem == 0 { return "\(hours)h" }
        return "\(hours)h \(rem)m"
    }

    static func longLabel(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours) hr" : "\(hours) hr \(rem) min"
    }
}

/// Inline chips: 10m · 30m · 1h · 2h+ · Custom… Tap again to clear (unknown).
struct DurationChipPicker: View {
    @Binding var minutes: Int?
    @State private var showCustom = false

    private let presets: [DurationChip] = [.ten, .thirty, .oneHour, .twoHoursPlus]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { chip in
                        chipButton(chip)
                    }
                    customChip
                }
                .padding(.vertical, 2)
            }

            Text(footerCopy)
                .font(.caption)
                .foregroundStyle(TaskWellTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(minutes: minutes ?? 30) { value in
                minutes = value
            }
        }
    }

    private var footerCopy: String {
        if minutes == nil {
            return "No selection means duration unknown."
        }
        if case .twoHoursPlus = DurationChip.matching(minutes) {
            return "2h+ is stored as 120 minutes — a stand-in for longer / open-ended work."
        }
        if case .custom = DurationChip.matching(minutes) {
            return "Custom: \(DurationFormatting.longLabel(minutes: minutes!))."
        }
        return "Tap the selected chip again to clear."
    }

    private func chipButton(_ chip: DurationChip) -> some View {
        let selected = DurationChip.matching(minutes) == chip
            || (chip == .twoHoursPlus && minutes == 120 && DurationChip.matching(minutes) == .twoHoursPlus)
        return Button {
            if selected {
                minutes = nil
            } else {
                minutes = chip.minutes
            }
        } label: {
            Text(chip.label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    selected ? TaskWellTheme.well : Color.white.opacity(0.9),
                    in: Capsule()
                )
                .foregroundStyle(selected ? Color.white : TaskWellTheme.wellDeep)
                .overlay(
                    Capsule()
                        .strokeBorder(TaskWellTheme.well.opacity(selected ? 0 : 0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var customChip: some View {
        let isCustom: Bool = {
            guard let minutes else { return false }
            return ![10, 30, 60, 120].contains(minutes)
        }()
        return Button {
            showCustom = true
        } label: {
            HStack(spacing: 4) {
                Text(isCustom ? DurationFormatting.label(minutes: minutes!) : "Custom…")
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isCustom ? TaskWellTheme.well : Color.white.opacity(0.9),
                in: Capsule()
            )
            .foregroundStyle(isCustom ? Color.white : TaskWellTheme.wellDeep)
            .overlay(
                Capsule()
                    .strokeBorder(TaskWellTheme.well.opacity(isCustom ? 0 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomDurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: Int
    var onSave: (Int) -> Void

    init(minutes: Int, onSave: @escaping (Int) -> Void) {
        let clamped = min(max(minutes, DurationFormatting.customRange.lowerBound), DurationFormatting.customRange.upperBound)
        let stepped = (clamped / DurationFormatting.customStep) * DurationFormatting.customStep
        _value = State(initialValue: max(DurationFormatting.customRange.lowerBound, stepped))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(DurationFormatting.longLabel(minutes: value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(TaskWellTheme.well)

                Picker("Minutes", selection: $value) {
                    ForEach(
                        Array(stride(
                            from: DurationFormatting.customRange.lowerBound,
                            through: DurationFormatting.customRange.upperBound,
                            by: DurationFormatting.customStep
                        )),
                        id: \.self
                    ) { minutes in
                        Text(DurationFormatting.longLabel(minutes: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 180)

                Text("5-minute steps · 5 min to 8 hr")
                    .font(.caption)
                    .foregroundStyle(TaskWellTheme.muted)
            }
            .padding()
            .navigationTitle("Custom duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(value)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
