import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text(timeText)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 160)
            Text(String(localized: String.LocalizationValue(statusKey)))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.s) {
                if app.engine.isSessionActive {
                    if app.engine.phase == .paused {
                        menuButton("focus.resume", "play.fill") { app.engine.resume() }
                    } else {
                        menuButton("focus.pause", "pause.fill") { app.engine.pause() }
                    }
                    if app.engine.isBreak {
                        menuButton("focus.skip.break", "forward.end.fill") { app.engine.skipBreak() }
                    }
                    menuButton("focus.abandon", "stop.fill") { app.engine.abandon() }
                } else {
                    menuButton("focus.start", "play.fill") { app.engine.startPomodoro() }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(width: 240)
    }

    private var timeText: String {
        if app.engine.mode == .free && app.engine.phase == .focusing {
            return format(app.engine.elapsed)
        }
        return format(app.engine.remaining)
    }

    private var statusKey: String {
        switch app.engine.phase {
        case .focusing: "focus.status.pomodoro"
        case .resting: "focus.status.resting"
        case .paused: "focus.status.paused"
        case .finished, .idle: "focus.status.idle"
        }
    }

    private func menuButton(_ key: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(String(localized: String.LocalizationValue(key)), systemImage: icon)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
