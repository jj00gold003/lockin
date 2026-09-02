import SwiftUI
import SwiftData

struct FocusView: View {
    @EnvironmentObject private var app: AppModel
    @Query(filter: #Predicate<TaskItem> { !$0.isCompleted },
           sort: [SortDescriptor(\TaskItem.priority, order: .reverse)])
    private var pendingTasks: [TaskItem]

    /// View-local mode selection (0 = pomodoro, 1 = free, 2 = countdown).
    /// Changing it only previews the mode via `engine.prepare`; starting a
    /// session is an explicit Start button action.
    @State private var selectedMode: Int = 0
    @State private var showAbandonConfirm = false
    @State private var customMinutesText = ""
    @AppStorage("countdownMinutes") private var countdownMinutes: Int = 25

    // Explicit init: the private @Query property would otherwise make the
    // synthesized memberwise initializer private and block `FocusView()`.
    init() {}

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            sessionPicker
            if selectedMode == 2 {
                countdownDurationChooser
            }
            TimerRingView(engine: app.engine)
            taskPicker
            controls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
        .onAppear(perform: syncSelectionOnAppear)
        .onChange(of: selectedMode) { _, newValue in
            previewMode(newValue)
        }
        .confirmationDialog(
            Text("focus.abandon.confirm.title"),
            isPresented: $showAbandonConfirm,
            titleVisibility: .visible
        ) {
            Button("focus.abandon.confirm.confirm", role: .destructive) {
                app.engine.abandon()
            }
            Button("common.cancel", role: .cancel) {}
        }
    }

    private func syncSelectionOnAppear() {
        if app.engine.isSessionActive {
            selectedMode = app.engine.mode == .free ? 1 : (app.engine.mode == .countdown ? 2 : 0)
        } else {
            app.engine.prepare(mode: .pomodoro)
        }
    }

    /// Only updates the idle preview — never starts a session.
    private func previewMode(_ modeIndex: Int) {
        switch modeIndex {
        case 1: app.engine.prepare(mode: .free)
        case 2: app.engine.prepare(mode: .countdown,
                                   countdownSeconds: Double(effectiveMinutes * 60))
        default: app.engine.prepare(mode: .pomodoro)
        }
    }

    private var sessionPicker: some View {
        Picker("", selection: $selectedMode) {
            Text("focus.mode.pomodoro").tag(0)
            Text("focus.mode.free").tag(1)
            Text("focus.mode.countdown").tag(2)
        }
        .pickerStyle(.segmented)
        .frame(width: 340)
        .disabled(app.engine.isSessionActive)
    }

    private var countdownDurationChooser: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes)") {
                    countdownMinutes = minutes
                    customMinutesText = ""
                    app.engine.prepare(mode: .countdown,
                                       countdownSeconds: Double(minutes * 60))
                }
                .buttonStyle(.bordered)
                .tint(isPresetSelected(minutes) ? Theme.accent(for: .focus) : .secondary)
            }
            TextField("focus.countdown.minutes", text: $customMinutesText)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .onChange(of: customMinutesText) { _, newValue in
                    handleCustomMinutesInput(newValue)
                }
            Text("focus.countdown.minutes")
                .foregroundStyle(.secondary)
        }
    }

    private func isPresetSelected(_ preset: Int) -> Bool {
        customMinutesText.isEmpty && countdownMinutes == preset
    }

    private func handleCustomMinutesInput(_ newValue: String) {
        let digits = newValue.filter { $0.isNumber }
        guard let raw = Int(digits) else {
            // Not a parseable number yet: keep only the digit characters.
            if digits != newValue { customMinutesText = digits }
            return
        }
        // Clamp into the valid 1...600 range and reflect the clamped value
        // back into the field instead of silently falling back at start time.
        let clamped = min(max(raw, 1), 600)
        countdownMinutes = clamped
        if digits != newValue && !digits.isEmpty {
            customMinutesText = digits
        }
        if String(clamped) != digits {
            customMinutesText = String(clamped)
        }
        if selectedMode == 2 {
            app.engine.prepare(mode: .countdown,
                               countdownSeconds: Double(clamped * 60))
        }
    }

    /// Minutes the Start button will use in countdown mode (1...600, default
    /// falls back to the persisted selection when the custom field is invalid).
    private var effectiveMinutes: Int {
        if let minutes = Int(customMinutesText), (1...600).contains(minutes) {
            return minutes
        }
        return min(max(countdownMinutes, 1), 600)
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
                    switch selectedMode {
                    case 1: app.engine.startFreeFocus()
                    case 2: app.engine.startCountdown(seconds: Double(effectiveMinutes * 60))
                    default: app.engine.startPomodoro()
                    }
                } label: {
                    Label("focus.start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(for: .focus))
            case .focusing, .resting:
                Button(role: .destructive) {
                    showAbandonConfirm = true
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
        case .focusing:
            switch engine.mode {
            case .free: "focus.status.free"
            case .countdown: "focus.status.countdown"
            default: "focus.status.pomodoro"
            }
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
