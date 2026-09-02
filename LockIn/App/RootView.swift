import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case focus, tasks, habits, stats
    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .focus: "sidebar.focus"
        case .tasks: "sidebar.tasks"
        case .habits: "sidebar.habits"
        case .stats: "sidebar.stats"
        }
    }

    var icon: String {
        switch self {
        case .focus: "timer"
        case .tasks: "checklist"
        case .habits: "flame"
        case .stats: "chart.bar"
        }
    }
}

struct RootView: View {
    @State private var selection: SidebarSection = .focus

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarSection.allCases) { section in
                    Label {
                        Text(String(localized: String.LocalizationValue(section.labelKey)))
                    } icon: {
                        Image(systemName: section.icon)
                            .foregroundStyle(Theme.accent(for: section))
                    }
                    .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            placeholder(for: selection)
        }
    }

    @ViewBuilder
    private func placeholder(for section: SidebarSection) -> some View {
        switch section {
        case .focus: FocusView()
        default: ContentUnavailableView(
            String(localized: String.LocalizationValue(section.labelKey)),
            systemImage: section.icon
        )
        }
    }
}
