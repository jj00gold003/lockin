import SwiftUI

// MARK: - PillPicker

/// One selectable option of a `PillPicker`.
struct PillOption<Tag: Hashable> {
    let labelKey: String
    let tag: Tag

    init(_ labelKey: String, tag: Tag) {
        self.labelKey = labelKey
        self.tag = tag
    }
}

/// Segmented-control replacement: text buttons in a rounded track, the
/// selected option highlighted by an accent-tinted capsule with a spring.
struct PillPicker<Tag: Hashable>: View {
    let options: [PillOption<Tag>]
    @Binding var selection: Tag
    var tint: Color = .accentColor
    var disabled = false
    var compact = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.tag) { option in
                let isSelected = option.tag == selection
                Button {
                    selection = option.tag
                } label: {
                    Text(String(localized: String.LocalizationValue(option.labelKey)))
                        .font(compact
                              ? Theme.Typography.caption.weight(.medium)
                              : Theme.Typography.body.weight(.medium))
                        .foregroundStyle(isSelected ? tint : Color.secondary)
                        .padding(.horizontal, compact ? 10 : 16)
                        .padding(.vertical, compact ? 4 : 6)
                        .background {
                            if isSelected {
                                Capsule().fill(tint.opacity(0.15))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.05), in: Capsule())
        .opacity(disabled ? 0.55 : 1)
        .disabled(disabled)
        .animation(Theme.Motion.spring, value: selection)
    }
}

// MARK: - Chip

/// Small rounded selectable chip (used for duration presets).
struct Chip: View {
    let text: String
    let isSelected: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Theme.Typography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? AnyShapeStyle(tint)
                        : AnyShapeStyle(Color.primary.opacity(0.06)),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
                )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.spring, value: isSelected)
    }
}

// MARK: - PrimaryButton

/// Prominent capsule button with a tint gradient and colored shadow.
struct PrimaryButton: View {
    let titleKey: String
    let icon: String
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .font(Theme.Typography.headline)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .shadow(color: tint.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StatTile

/// Stat summary tile: icon in a tinted rounded square, big rounded number,
/// caption label. Replaces the flat stat cards.
struct StatTile: View {
    let value: String
    let labelKey: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(Theme.Typography.stat)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(String(localized: String.LocalizationValue(labelKey)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, y: Theme.Shadow.card.y)
    }
}

// MARK: - SectionHeader

/// Small-caps secondary section header with optional trailing content.
struct SectionHeader<Trailing: View>: View {
    let titleKey: String
    let trailing: Trailing

    init(titleKey: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.titleKey = titleKey
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            trailing
        }
    }
}

// MARK: - EmptyStateView

/// Centered empty-state placeholder with a tinted icon circle.
struct EmptyStateView: View {
    let icon: String
    let titleKey: String
    var subtitleKey: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.12), in: Circle())
            Text(String(localized: String.LocalizationValue(titleKey)))
                .font(Theme.Typography.headline)
                .foregroundStyle(.secondary)
            if let subtitleKey {
                Text(String(localized: String.LocalizationValue(subtitleKey)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
