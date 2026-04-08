import SwiftUI

/// Shows an estimated token count and approximate cost before a user
/// triggers an expensive AI call. Displayed as a subtle info row.
struct TokenEstimateView: View {
    let estimatedTokens: Int
    /// Provider name shown in the label, e.g. "OpenAI".
    var providerName: String = "AI"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(.secondary)
                .imageScale(.small)
            Text("~\(estimatedTokens.formatted()) tokens (\(providerName))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TokenEstimateView(estimatedTokens: 3_400, providerName: "Anthropic")
        .padding()
}
