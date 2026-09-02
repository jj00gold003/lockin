import SwiftUI

enum Theme {
    static func accent(for section: SidebarSection) -> Color {
        switch section {
        case .focus: Color(red: 0.95, green: 0.45, blue: 0.30)
        case .tasks: Color(red: 0.30, green: 0.56, blue: 0.95)
        case .habits: Color(red: 0.30, green: 0.72, blue: 0.48)
        case .stats: Color(red: 0.55, green: 0.45, blue: 0.90)
        }
    }

    /// Spacing scale
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }

    /// Card container: large corner radius + soft shadow
    struct Card<Content: View>: View {
        let content: Content
        init(@ViewBuilder content: () -> Content) { self.content = content() }
        var body: some View {
            content
                .padding(Spacing.m)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }
}
