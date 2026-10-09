import SwiftUI

enum AppTheme {
    // Softer green tones sampled from the official OwlMate artwork.
    static let accent = Color(red: 0.24, green: 0.49, blue: 0.32)
    static let navy = Color(red: 0.10, green: 0.23, blue: 0.16)
    static let lavender = Color(red: 0.88, green: 0.94, blue: 0.87)
    static let cream = Color(red: 0.95, green: 0.97, blue: 0.91)
    static let sage = Color(red: 0.38, green: 0.62, blue: 0.43)
    static let gold = Color(red: 0.83, green: 0.67, blue: 0.28)
    static let chatAssistant = Color(uiColor: .secondarySystemBackground)
    static let chatComposer = Color(uiColor: .systemBackground)
    static let chatBackground = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let separator = Color(uiColor: .separator).opacity(0.55)
    static let avatarSurface = Color(uiColor: .systemBackground)
    static let homeBackground = Color(uiColor: .systemBackground)
    static let lavenderSurface = Color(red: 0.89, green: 0.95, blue: 0.88)
    static let lavenderSurfaceDark = Color(red: 0.18, green: 0.30, blue: 0.23)
    static let statusSurface = Color(uiColor: .secondarySystemBackground)
    static let success = sage
    static let warning = gold
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
