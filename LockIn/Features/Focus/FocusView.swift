import SwiftUI
import SwiftData

struct FocusView: View {
    @EnvironmentObject private var app: AppModel
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: [SortDescriptor(\TaskItem.priority, order: .reverse)])
    private var pendingTasks: [TaskItem]

    // Explicit init: the private @Query property would otherwise make the
    // synthesized memberwise initializer private and block `FocusView()`.
    init() {}

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            sessionPicker
            TimerRingView(engine: app.engine)
            taskPicker
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }

    private var sessionPicker: some View {
        Picker("", selection: pickerBinding) {
            Text("focus.mode.pomodoro").tag(0)
            Text("focus.mode.free").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(width: 260)
        .disabled(app.engine.isSessionActive)
    }

    private var pickerBinding: Binding<Int> {
        Binding(
            get: { app.engine.mode == .free ? 1 : 0 },
            set: { newValue in
                if newValue == 1 { app.engine.startFreeFocus() } else { app.engine.startPomodoro() }
            }
        )
    }

    // Manual binding: AppModel.focus is a `let`, so $app.focus dynamic-member
    // lookup cannot form a writable key path.
    private var taskBinding: Binding<UUID?> {
        Binding(
            get: { app.focus.selectedTaskID },
            set: { app.focus.selectedTaskID = $0 }
        )
    }

    private var taskPicker: some View {
        Picker("focus.link.task", selection: taskBinding) {
            Text("focus.task.none").tag(UUID?.none)
            ForEach(pendingTasks) { task in
                Text(task.title).tag(UUID?.some(task.id))
            }
        }
        .frame(width: 320)
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.m) {
            switch app.engine.phase {
            case .idle, .finished:
                Button {
                    app.engine.startPomodoro()
                } label: {
                    Label("focus.start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(for: .focus))
            case .focusing, .resting:
                Button(role: .destructive) {
                    app.engine.abandon()
                } label: {
                    Label("focus.abandon", systemImage: "stop.fill")
                }
                if app.engine.isBreak {
                    Button {
                        app.engine.skipBreak()
                    } label: {
                        Label("focus.skip.break", systemImage: "forward.end.fill")
                    }
                }
            case .paused:
                Button {
                    app.engine.resume()
                } label: {
                    Label("focus.resume", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(for: .focus))
            }
        }
    }
}

/// Ring progress + monospaced large digits.
struct TimerRingView: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            VStack(spacing: Theme.Spacing.xs) {
                Text(timeText)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(String(localized: String.LocalizationValue(statusText)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 280, height: 280)
    }

    private var progress: Double {
        guard engine.currentPhaseDuration > 0 else { return 0.0 }
        return 1 - engine.remaining / engine.currentPhaseDuration
    }

    private var tint: Color {
        engine.isBreak ? Theme.accent(for: .habits) : Theme.accent(for: .focus)
    }

    private var timeText: String {
        if engine.mode == .free && engine.phase == .focusing {
            return format(engine.elapsed)
        }
        return format(engine.remaining)
    }

    private var statusText: String {
        switch engine.phase {
        case .focusing: engine.mode == .free ? "focus.status.free" : "focus.status.pomodoro"
        case .resting: "focus.status.resting"
        case .paused: "focus.status.paused"
        case .finished: "focus.status.done"
        case .idle: "focus.status.idle"
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
