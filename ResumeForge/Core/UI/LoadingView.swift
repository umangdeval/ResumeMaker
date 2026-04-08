import SwiftUI

/// Full-screen loading overlay with an optional message.
struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

/// Inline progress row used inside lists or forms.
struct InlineLoadingRow: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().progressViewStyle(.circular)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LoadingView(message: "Consulting AI Council…")
}
