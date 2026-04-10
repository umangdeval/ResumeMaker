import SwiftUI

enum AppTheme {
    static let bg = Color.black
    static let surface = Color(.sRGB, red: 245 / 255, green: 245 / 255, blue: 247 / 255, opacity: 1)
    static let text = Color(.sRGB, red: 29 / 255, green: 29 / 255, blue: 31 / 255, opacity: 1)
    static let textSecondary = Color(.sRGB, red: 29 / 255, green: 29 / 255, blue: 31 / 255, opacity: 0.72)
    static let blue = Color(.sRGB, red: 0 / 255, green: 113 / 255, blue: 227 / 255, opacity: 1)

    static let heroTitle = Font.system(size: 34, weight: .semibold)
    static let sectionTitle = Font.system(size: 21, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
}

private struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.22), radius: 18, x: 3, y: 5)
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }

    func appCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }
}
