import SwiftUI

extension View {
    /// Overlays a full-screen `LoadingView` when `isLoading` is true.
    @ViewBuilder
    func loadingOverlay(_ isLoading: Bool, message: String = "Loading…") -> some View {
        overlay {
            if isLoading {
                LoadingView(message: message)
            }
        }
    }

    /// Presents an `ErrorBanner` below the view when `error` is non-nil.
    @ViewBuilder
    func errorBanner(_ error: Error?) -> some View {
        VStack(spacing: 0) {
            self
            if let error {
                ErrorBanner(message: error.localizedDescription)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error != nil)
    }
}
