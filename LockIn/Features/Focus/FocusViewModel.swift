import Foundation
import Combine

/// Bridges TimerEngine phase transitions to FocusSession persistence.
/// One session row per focus segment: a row starts on first entering
/// `.focusing` and settles when focus ends — either at the focus→resting
/// boundary (status "completed") or on `.finished` (status derived from
/// `lastEndReason`). Pause time is excluded from the seconds credited to
/// the linked task.
@MainActor
final class FocusViewModel: ObservableObject {
    @Published var selectedTaskID: UUID?

    private let engine: TimerEngine
    private let sessionRepo: SessionRepository
    private let taskRepo: TaskRepository
    private var currentSessionID: UUID?
    private var lastSettledPausedSeconds: TimeInterval = 0
    private var cancellables: Set<AnyCancellable> = []

    init(engine: TimerEngine, sessionRepo: SessionRepository, taskRepo: TaskRepository) {
        self.engine = engine
        self.sessionRepo = sessionRepo
        self.taskRepo = taskRepo
        engine.$phase
            .removeDuplicates()
            .sink { [weak self] phase in self?.phaseChanged(phase) }
            .store(in: &cancellables)
    }

    private func phaseChanged(_ phase: TimerEngine.Phase) {
        switch phase {
        case .focusing where currentSessionID == nil && engine.mode != .none:
            lastSettledPausedSeconds = engine.pausedSeconds
            let type: String
            switch engine.mode {
            case .free: type = "free"
            case .countdown: type = "countdown"
            default: type = "pomodoro"
            }
            let session = sessionRepo.start(type: type, taskID: selectedTaskID,
                                            at: engine.currentTime())
            currentSessionID = session.id
        case .resting where currentSessionID != nil:
            settleCurrentSession(status: "completed")
        case .finished:
            settleCurrentSession(status: engine.lastEndReason == .abandoned ? "abandoned" : "completed")
        default:
            break
        }
    }

    private func settleCurrentSession(status: String) {
        guard let id = currentSessionID else { return }
        let pausedDelta = engine.pausedSeconds - lastSettledPausedSeconds
        lastSettledPausedSeconds = engine.pausedSeconds
        let session = sessionRepo.incomplete().first { $0.id == id }
        if let session {
            // Use the engine's clock (not Date.now) so tests with a fake clock
            // measure wall time on the same timeline as the session start.
            let wall = engine.currentTime().timeIntervalSince(session.startedAt)
            let focusingSeconds = max(0, wall - pausedDelta)
            sessionRepo.finish(id: id, status: status,
                               interruptions: engine.interruptionCount,
                               at: engine.currentTime())
            if let taskID = session.taskID { taskRepo.addFocusSeconds(focusingSeconds, to: taskID) }
        } else {
            sessionRepo.finish(id: id, status: status,
                               interruptions: engine.interruptionCount,
                               at: engine.currentTime())
        }
        currentSessionID = nil
    }
}
