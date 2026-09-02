import Foundation
import Combine

public struct PomodoroConfig: Equatable {
    public var focusSeconds: TimeInterval = 25 * 60
    public var shortBreakSeconds: TimeInterval = 5 * 60
    public var longBreakSeconds: TimeInterval = 15 * 60
    public var roundsBeforeLongBreak: Int = 4
    public init(focusSeconds: TimeInterval = 25 * 60,
                shortBreakSeconds: TimeInterval = 5 * 60,
                longBreakSeconds: TimeInterval = 15 * 60,
                roundsBeforeLongBreak: Int = 4) {
        self.focusSeconds = focusSeconds
        self.shortBreakSeconds = shortBreakSeconds
        self.longBreakSeconds = longBreakSeconds
        self.roundsBeforeLongBreak = roundsBeforeLongBreak
    }
}

/// Pure-logic timer state machine: no SwiftUI import, no UI dependencies.
/// Timing is based on an anchor timestamp; it self-corrects after sleep/wake
/// or hiccups and never accumulates second by second.
@MainActor
public final class TimerEngine: ObservableObject {
    public enum Phase: Equatable { case idle, focusing, paused, resting, finished }
    public enum Mode: Equatable { case none, pomodoro, free, countdown }
    public enum EndReason: Equatable { case none, abandoned, completed }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var mode: Mode = .none
    @Published public private(set) var round: Int = 0
    @Published public private(set) var remaining: TimeInterval = 0
    @Published public private(set) var elapsed: TimeInterval = 0

    public private(set) var interruptionCount: Int = 0
    public private(set) var lastEndReason: EndReason = .none
    /// Total seconds spent paused during the current engine run
    public private(set) var pausedSeconds: TimeInterval = 0
    private var pausedAt: Date?

    public var isSessionActive: Bool {
        phase == .focusing || phase == .paused || phase == .resting
    }
    public var isBreak: Bool { phase == .resting }
    /// Read-only exposure of the current phase's planned duration (0 = unlimited, free mode).
    public var currentPhaseDuration: TimeInterval { phaseDuration }

    /// The engine's clock, exposed so persistence layers can timestamp records
    /// on the same timeline the engine measures against (tests inject a fake clock).
    public func currentTime() -> Date { now() }

    private let config: PomodoroConfig
    private let now: () -> Date
    private var anchor: Date?
    private var phaseDuration: TimeInterval = 0
    private var pausedPhase: Phase?
    private var pausedRemaining: TimeInterval = 0
    private var pausedElapsed: TimeInterval = 0
    private var sleepDate: Date?
    private var ticker: Timer?

    public init(config: PomodoroConfig = PomodoroConfig(), now: @escaping () -> Date = Date.init) {
        self.config = config
        self.now = now
    }

    // MARK: - Session control

    public func startPomodoro() {
        mode = .pomodoro; round = 1; interruptionCount = 0; lastEndReason = .none
        pausedSeconds = 0; pausedAt = nil
        beginPhase(.focusing, duration: config.focusSeconds)
    }

    public func startFreeFocus() {
        mode = .free; round = 1; interruptionCount = 0; lastEndReason = .none
        pausedSeconds = 0; pausedAt = nil
        beginPhase(.focusing, duration: 0) // 0 = no upper limit
    }

    public func startCountdown(seconds: TimeInterval) {
        mode = .countdown; round = 1; interruptionCount = 0; lastEndReason = .none
        pausedSeconds = 0; pausedAt = nil
        beginPhase(.focusing, duration: seconds)
    }

    /// Preview a mode without starting a session (idle phase, no ticker)
    public func prepare(mode: Mode, countdownSeconds: TimeInterval = 0) {
        guard !isSessionActive else { return }
        stopTicker()
        self.mode = mode
        round = 1
        interruptionCount = 0
        lastEndReason = .none
        anchor = nil
        phase = .idle
        phaseDuration = mode == .pomodoro ? config.focusSeconds : (mode == .countdown ? countdownSeconds : 0)
        elapsed = 0
        remaining = phaseDuration
    }

    public func pause() {
        guard phase == .focusing || phase == .resting else { return }
        interruptionCount += 1
        pausedPhase = phase
        pausedRemaining = remaining
        pausedElapsed = elapsed
        phase = .paused
        pausedAt = now()
        stopTicker()
    }

    public func resume() {
        guard phase == .paused, let paused = pausedPhase else { return }
        if let pausedAt {
            pausedSeconds += now().timeIntervalSince(pausedAt)
        }
        pausedAt = nil
        phase = paused
        if phaseDuration > 0 {
            anchor = now().addingTimeInterval(-(phaseDuration - pausedRemaining))
        } else {
            anchor = now().addingTimeInterval(-pausedElapsed)
        }
        pausedPhase = nil
        startTicker()
        publishTime()
    }

    public func skipBreak() {
        guard phase == .resting else { return }
        round += 1
        beginPhase(.focusing, duration: config.focusSeconds)
    }

    public func abandon() {
        guard isSessionActive else { return }
        if let started = pausedAt {
            pausedSeconds += now().timeIntervalSince(started)
            pausedAt = nil
        }
        stopTicker()
        lastEndReason = .abandoned
        anchor = nil
        phase = .finished
    }

    // MARK: - Heartbeat

    /// Called once per second by UI and tests; all time derivation happens here.
    public func tick() {
        guard let anchor, isSessionActive, phase != .paused else { return }
        let passed = now().timeIntervalSince(anchor)
        elapsed = passed
        if phaseDuration > 0 {
            remaining = max(0, phaseDuration - passed)
            if remaining == 0 { handlePhaseEnd() }
        }
    }

    private func handlePhaseEnd() {
        if phase == .focusing {
            if mode == .countdown {
                // A countdown is a single bounded focus: ending it ends the
                // session entirely (no break, next round, or auto-restart).
                stopTicker()
                lastEndReason = .completed
                anchor = nil
                phase = .finished
                return
            }
            let isLongBreak = mode == .pomodoro && round % config.roundsBeforeLongBreak == 0
            let breakDuration = isLongBreak ? config.longBreakSeconds : config.shortBreakSeconds
            beginPhase(.resting, duration: breakDuration)
        } else if phase == .resting {
            round += 1
            beginPhase(.focusing, duration: config.focusSeconds)
        }
    }

    // MARK: - Sleep/wake (behavior completed in Task 13)

    public func handleSleep() { sleepDate = now() }

    public func handleWake() {
        guard let sleepDate else { return }
        let slept = now().timeIntervalSince(sleepDate)
        self.sleepDate = nil
        if phase == .resting, phaseDuration > 0, slept > phaseDuration {
            round += 1
            beginPhase(.focusing, duration: config.focusSeconds)
        } else {
            tick()
        }
    }

    // MARK: - Private

    private func beginPhase(_ newPhase: Phase, duration: TimeInterval) {
        phase = newPhase
        phaseDuration = duration
        anchor = now()
        startTicker()
        publishTime()
    }

    private func publishTime() {
        guard let anchor else { return }
        let passed = now().timeIntervalSince(anchor)
        elapsed = passed
        remaining = phaseDuration > 0 ? max(0, phaseDuration - passed) : 0
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
