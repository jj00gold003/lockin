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
        ZStack {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(210)
            } detail: {
                detail(for: selection)
            }
            RecoveryView()
        }
    }

    // MARK: - Sidebar (brand header + nav rows + pinned settings)

    private var sidebar: some View {
        VStack(spacing: Theme.Spacing.s) {
            brandHeader
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xs)

            VStack(spacing: 2) {
                ForEach(SidebarSection.allCases) { section in
                    SidebarRow(section: section, isSelected: selection == section) {
                        selection = section
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s)

            Spacer(minLength: 0)

            Divider()
                .padding(.horizontal, Theme.Spacing.m)
            settingsLink
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, Theme.Spacing.s)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(colors: [Theme.accent(for: .focus),
                                            Theme.accent(for: .focus).opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control)
                )
            Text("LockIn")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private var settingsLink: some View {
        SettingsLink {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 7))
                Text("settings.title")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detail(for section: SidebarSection) -> some View {
        switch section {
        case .focus: FocusView()
        case .tasks: TasksView()
        case .habits: HabitsView()
        case .stats: StatsView()
        default: ContentUnavailableView(
            String(localized: String.LocalizationValue(section.labelKey)),
            systemImage: section.icon
        )
        }
    }
}

// MARK: - Nav row

private struct SidebarRow: View {
    let section: SidebarSection
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent(for: section))
                    .frame(width: 24, height: 24)
                    .background(Theme.accent(for: section).opacity(isSelected ? 0.18 : 0.10),
                                in: RoundedRectangle(cornerRadius: 7))
                Text(String(localized: String.LocalizationValue(section.labelKey)))
                    .font(Theme.Typography.body.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                Spacer()
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(rowFill)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(Theme.Motion.hover, value: isSelected)
        .animation(Theme.Motion.hover, value: hovered)
    }

    private var rowFill: Color {
        if isSelected { return Theme.accent(for: section).opacity(0.12) }
        return hovered ? Color.primary.opacity(0.04) : .clear
    }
}
