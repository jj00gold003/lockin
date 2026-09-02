import Foundation
import SwiftData
import Combine
import AppKit

/// App-level dependency container: engine + repositories + per-feature ViewModels.
@MainActor
final class AppModel: ObservableObject {
    /// Reachable from non-SwiftUI entry points (e.g. the AppDelegate's
    /// quit-confirmation hook).
    static weak var shared: AppModel?

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

        // Relay TimerEngine changes into AppModel so views observing AppModel
        // (e.g. MenuBarExtra label/panel) re-render when the engine ticks.
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Expose the instance once fully initialized so the AppDelegate can
        // reach it from applicationShouldTerminate.
        AppModel.shared = self
    }

    // MARK: - Lifecycle (Task 13: sleep/wake wiring + crash recovery)

    /// Leftover "running" session found at launch; non-nil shows RecoveryView.
    @Published var pendingRecovery: FocusSession?

    /// Guard so `.task` re-fires (root view reappearing) never add duplicate
    /// NSWorkspace observers. Observers are added exactly once per AppModel.
    private var lifecycleStarted = false

    func startLifecycleObservers() {
        guard !lifecycleStarted else { return }
        lifecycleStarted = true
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.engine.handleSleep() }
        }
        center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.engine.handleWake() }
        }
    }

    /// Launch-time check: any session still marked "running" means the app
    /// crashed or was force-quit mid-focus; surface it for recovery.
    func checkPendingRecovery() {
        pendingRecovery = sessionRepo.incomplete().first
    }

    func resolveRecovery(_ choice: RecoveryChoice) {
        guard let session = pendingRecovery else { return }
        switch choice {
        case .continueWork:
            // The crashed run can no longer be measured reliably; settle it as
            // abandoned, then jump straight into a new free focus on the same task.
            sessionRepo.resolve(id: session.id, to: "abandoned",
                                endedAt: session.startedAt.addingTimeInterval(1))
            focus.selectedTaskID = session.taskID
            engine.startFreeFocus()
        case .markCompleted:
            // Settle without counting duration (+1s, consistent with continueWork).
            sessionRepo.resolve(id: session.id, to: "completed",
                                endedAt: session.startedAt.addingTimeInterval(1))
        case .discard:
            sessionRepo.resolve(id: session.id, to: "abandoned",
                                endedAt: session.startedAt.addingTimeInterval(1))
        }
        pendingRecovery = nil
    }

    enum RecoveryChoice { case continueWork, markCompleted, discard }

    // MARK: - Blocker (Task 9: soft block overlay)

    let monitor = FrontmostAppMonitor()
    let blocker = BlockerController()
    let cover = WindowCoverController()
    let banner = BannerController()
    private var cancellables: Set<AnyCancellable> = []

    func startBlocker() {
        monitor.start()
        blocker.start(
            monitor: monitor,
            rulesProvider: { [weak self] in
                self?.effectiveRules() ?? []
            },
            sessionActive: { [weak self] in self?.engine.isSessionActive ?? false },
            onHardBlock: { [weak self] decision in
                guard let self else { return }
                if decision.action == .hard, AccessibilityGuard.isGranted(),
                   let running = self.hitApp(for: decision) {
                    _ = AccessibilityGuard.minimize(app: running)
                }
            }
        )
        blocker.$activeBlock
            .sink { [weak self] decision in
                guard let self else { return }
                if let decision {
                    // Banner is per-event and non-interactive: show it whenever a
                    // block fires, even outside a session (always-scope rules).
                    self.banner.show(appName: self.blockedAppName(for: decision))
                    if self.engine.isSessionActive {
                        // Covers are per-window and nil-safe: an unresolvable
                        // target app simply gets no covers.
                        if let app = self.hitApp(for: decision) {
                            self.cover.showCovers(for: app,
                                                  engine: self.engine,
                                                  blocker: self.blocker)
                        } else {
                            self.cover.hideAll()
                        }
                    } else {
                        self.cover.hideAll()
                    }
                } else {
                    self.cover.hideAll()
                }
            }
            .store(in: &cancellables)
        engine.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                if phase == .idle || phase == .finished { self?.sessionRules = nil }
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

    /// Find the running app for a block decision via its rule's bundle ID.
    private func hitApp(for decision: BlockDecision) -> NSRunningApplication? {
        let rules = ruleRepo.all()
        guard let rule = rules.first(where: { $0.id == decision.ruleID }) else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == rule.bundleID
        }
    }

    /// Best-effort display name for banner copy: the running app's localized
    /// name, falling back to the rule's stored app name.
    private func blockedAppName(for decision: BlockDecision) -> String {
        let rules = ruleRepo.all()
        guard let rule = rules.first(where: { $0.id == decision.ruleID }) else { return "" }
        return hitApp(for: decision)?.localizedName ?? rule.appDisplayName
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
