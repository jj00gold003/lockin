import SwiftUI

/// Compact per-window cover content: replaces the old full-screen overlay.
struct BlockCoverView: View {
    @ObservedObject var engine: TimerEngine
    let appName: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent(for: .focus))
            Text("block.cover.title")
                .font(.headline)
                .foregroundStyle(.white)
            Text(appName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent(for: .focus))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Theme.Spacing.s)
            Text(timeText)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.white)
            Text("block.cover.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.97))
        )
    }

    private var timeText: String {
        let s = Int(engine.remaining.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
