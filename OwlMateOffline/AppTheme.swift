import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.22, green: 0.48, blue: 0.78)
    static let navy = Color(red: 0.08, green: 0.13, blue: 0.23)
    static let lavender = Color(red: 0.91, green: 0.89, blue: 0.98)
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.93)
    static let chatAssistant = Color(uiColor: .secondarySystemBackground)
    static let chatComposer = Color(uiColor: .systemBackground)
    static let chatBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let separator = Color(uiColor: .separator).opacity(0.55)
    static let avatarSurface = Color(uiColor: .systemBackground)
    static let homeBackground = Color(uiColor: .systemBackground)
    static let lavenderSurface = Color(red: 0.92, green: 0.90, blue: 0.98)
    static let lavenderSurfaceDark = Color(red: 0.23, green: 0.21, blue: 0.34)
    static let statusSurface = Color(uiColor: .secondarySystemBackground)
    static let success = Color.green
    static let warning = Color.orange
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackground())
    }
}
