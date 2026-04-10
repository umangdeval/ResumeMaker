import SwiftUI

/// Full-screen loading overlay with an optional message.
struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}

/// Inline progress row used inside lists or forms.
struct InlineLoadingRow: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().progressViewStyle(.circular)
                .tint(AppTheme.blue)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

#Preview {
    LoadingView(message: "Consulting AI Council…")
}
