import SwiftUI

/// Calm sea-well palette: deep teal ink, soft mist, warm coral accent.
enum TaskWellTheme {
    static let ink = Color(red: 0.10, green: 0.22, blue: 0.28)
    static let mist = Color(red: 0.93, green: 0.96, blue: 0.95)
    static let well = Color(red: 0.18, green: 0.52, blue: 0.48)
    static let wellDeep = Color(red: 0.12, green: 0.38, blue: 0.40)
    static let coral = Color(red: 0.92, green: 0.45, blue: 0.32)
    static let sand = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let muted = Color(red: 0.42, green: 0.50, blue: 0.52)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.95, blue: 0.94),
                Color(red: 0.96, green: 0.94, blue: 0.90),
                Color(red: 0.88, green: 0.93, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [wellDeep, well],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(TaskWellTheme.well)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.ink)
                Text(message)
                    .font(.body)
                    .foregroundStyle(TaskWellTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(TaskWellTheme.well)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    var retryTitle: String = "Try again"
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskWellTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let retry {
                Button(retryTitle, action: retry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaskWellTheme.coral)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskWellTheme.sand.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(TaskWellTheme.coral.opacity(0.35), lineWidth: 1)
        )
    }
}

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(TaskWellTheme.well)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TaskWellTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func taskWellScreenBackground() -> some View {
        background(TaskWellTheme.backgroundGradient.ignoresSafeArea())
    }
}
