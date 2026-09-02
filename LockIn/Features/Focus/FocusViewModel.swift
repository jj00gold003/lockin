import Foundation
import Combine

/// Bridges TimerEngine phase transitions to FocusSession persistence:
/// starts a session on first entering `.focusing`, finishes it on `.finished`
/// with a status derived from `lastEndReason`, and accumulates focus seconds
/// onto the linked task.
@MainActor
final class FocusViewModel: ObservableObject {
    @Published var selectedTaskID: UUID?

    private let engine: TimerEngine
    private let sessionRepo: SessionRepository
    private let taskRepo: TaskRepository
    private var currentSessionID: UUID?
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
            let type = engine.mode == .free ? "free" : "pomodoro"
            let session = sessionRepo.start(type: type, taskID: selectedTaskID)
            currentSessionID = session.id
        case .finished:
            guard let id = currentSessionID else { return }
            let status = engine.lastEndReason == .abandoned ? "abandoned" : "completed"
            let session = sessionRepo.incomplete().first { $0.id == id }
            let duration = session.map { ($0.endedAt ?? .now).timeIntervalSince($0.startedAt) } ?? 0
            sessionRepo.finish(id: id, status: status, interruptions: engine.interruptionCount)
            if let taskID = session?.taskID { taskRepo.addFocusSeconds(duration, to: taskID) }
            currentSessionID = nil
        default:
            break
        }
    }
}
