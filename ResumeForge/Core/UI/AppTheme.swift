import SwiftUI

enum AppTheme {
    // MARK: - Adaptive colors (light + dark mode)
    static let bg             = Color(nsColor: .windowBackgroundColor)
    static let surface        = Color(nsColor: .controlBackgroundColor)
    static let text           = Color(nsColor: .labelColor)
    static let textSecondary  = Color(nsColor: .secondaryLabelColor)
    static let separator      = Color(nsColor: .separatorColor)
    static let blue           = Color.accentColor

    // MARK: - macOS HIG font scale
    static let heroTitle    = Font.system(size: 20, weight: .semibold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let body         = Font.system(size: 13, weight: .regular)
    static let caption      = Font.system(size: 11, weight: .regular)

    static let contentMaxWidth: CGFloat = 900
}

// MARK: - View modifiers

private struct AppScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.separator, lineWidth: 0.5)
            )
    }
}

private struct AppContentWidthModifier: ViewModifier {
    var maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct AppFormCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.text)
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }

    func appCard(cornerRadius: CGFloat = 8) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }

    func appContentWidth(_ maxWidth: CGFloat = AppTheme.contentMaxWidth) -> some View {
        modifier(AppContentWidthModifier(maxWidth: maxWidth))
    }

    func appFormCard() -> some View {
        modifier(AppFormCardModifier())
    }
}
