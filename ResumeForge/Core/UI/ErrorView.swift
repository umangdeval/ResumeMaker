import SwiftUI

/// Reusable error state view with a retry action.
struct ErrorView: View {
    let error: Error
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42))
                .foregroundStyle(.white)
            Text("Something went wrong")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
            Text(error.localizedDescription)
                .font(AppTheme.body)
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
    }
}

/// Inline error banner used inside forms or lists.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ErrorView(error: AIServiceError.missingAPIKey(provider: "OpenAI")) {
        print("Retry tapped")
    }
}
