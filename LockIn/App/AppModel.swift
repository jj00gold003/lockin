import Foundation
import SwiftData
import Combine

/// App-level dependency container: engine + repositories + per-feature ViewModels.
@MainActor
final class AppModel: ObservableObject {
    let engine: TimerEngine
    let taskRepo: TaskRepository
    let sessionRepo: SessionRepository
    let habitRepo: HabitRepository
    let ruleRepo: BlockRuleRepository
    let focus: FocusViewModel

    init(container: ModelContainer) {
        let context = ModelContext(container)
        engine = TimerEngine()
        taskRepo = TaskRepository(context: context)
        sessionRepo = SessionRepository(context: context)
        habitRepo = HabitRepository(context: context)
        ruleRepo = BlockRuleRepository(context: context)
        focus = FocusViewModel(engine: engine,
                               sessionRepo: sessionRepo,
                               taskRepo: taskRepo)
    }

    // MARK: - Blocker (Task 9: soft block overlay)

    let monitor = FrontmostAppMonitor()
    let blocker = BlockerController()
    let overlay = BlockOverlayWindowController()
    private var cancellables: Set<AnyCancellable> = []

    func startBlocker() {
        monitor.start()
        blocker.start(
            monitor: monitor,
            rulesProvider: { [weak self] in
                self?.effectiveRules() ?? []
            },
            sessionActive: { [weak self] in self?.engine.isSessionActive ?? false }
        )
        blocker.$activeBlock
            .sink { [weak self] decision in
                guard let self else { return }
                if decision != nil, self.engine.isSessionActive {
                    self.overlay.show(engine: self.engine, blocker: self.blocker)
                } else {
                    self.overlay.hide()
                }
            }
            .store(in: &cancellables)
    }

    /// spec 4.3 anti-cheat: lock a rules snapshot when a session starts; mid-session rule edits don't apply
    private var sessionRules: [RuleSnapshot]?

    private func effectiveRules() -> [RuleSnapshot] {
        if engine.isSessionActive {
            if let sessionRules { return sessionRules }
            let fresh = ruleRepo.all().compactMap { snapshot(from: $0) }
            sessionRules = fresh
            return fresh
        } else {
            sessionRules = nil
            return ruleRepo.all().compactMap { snapshot(from: $0) }
        }
    }

    private func snapshot(from rule: BlockRule) -> RuleSnapshot? {
        guard let level = BlockLevel(rawValue: rule.level),
              let scope = BlockScope(rawValue: rule.scope) else { return nil }
        let windows = (try? JSONDecoder().decode([ScheduleWindow].self,
                                                 from: Data(rule.scheduleJSON.utf8))) ?? []
        return RuleSnapshot(id: rule.id, bundleID: rule.bundleID, level: level,
                            scope: scope, windows: windows, isEnabled: rule.isEnabled)
    }
}
