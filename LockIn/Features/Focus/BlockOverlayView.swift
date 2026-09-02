import SwiftUI

struct BlockOverlayView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var blocker: BlockerController

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent(for: .focus))
            Text("focus.blocked.title")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(timeText)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.accent(for: .focus))
            Text("focus.blocked.subtitle")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: blocker.activeBlock?.ruleID)
    }

    private var timeText: String {
        let s = Int(engine.remaining.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
