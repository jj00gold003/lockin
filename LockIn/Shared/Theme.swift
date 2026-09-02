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

    /// Corner radius scale
    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 10
        static let chip: CGFloat = 8
    }

    /// Typography scale (rounded display faces for numbers/headers)
    enum Typography {
        static let display: Font = .system(size: 56, weight: .semibold, design: .rounded)
        static let title: Font = .system(size: 22, weight: .bold, design: .rounded)
        static let stat: Font = .system(size: 24, weight: .bold, design: .rounded)
        static let headline: Font = .system(size: 15, weight: .semibold)
        static let body: Font = .system(size: 14)
        static let caption: Font = .system(size: 12)
    }

    /// Elevation levels
    enum Shadow {
        struct Level {
            let color: Color
            let radius: CGFloat
            let y: CGFloat
        }

        /// Resting cards and rows.
        static let card = Level(color: .black.opacity(0.08), radius: 10, y: 2)
        /// Floating elements (prominent buttons, popovers).
        static let floating = Level(color: .black.opacity(0.12), radius: 20, y: 6)
    }

    /// Standard motion curves
    enum Motion {
        static let spring = Animation.spring(duration: 0.25)
        static let hover = Animation.easeInOut(duration: 0.2)
    }

    /// Card container: large corner radius + soft shadow
    struct Card<Content: View>: View {
        let content: Content
        init(@ViewBuilder content: () -> Content) { self.content = content() }
        var body: some View {
            content
                .padding(Spacing.m)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.card))
                .shadow(color: Shadow.card.color, radius: Shadow.card.radius, y: Shadow.card.y)
        }
    }
}
