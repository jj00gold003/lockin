import XCTest
import SwiftData
@testable import LockIn

@MainActor
final class FocusViewModelTests: XCTestCase {
    private var fakeNow: Date!
    private var engine: TimerEngine!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var sessionRepo: SessionRepository!
    private var taskRepo: TaskRepository!
    private var vm: FocusViewModel!

    override func setUp() {
        fakeNow = Date(timeIntervalSince1970: 1_700_000_000)
        engine = TimerEngine(now: { [weak self] in self?.fakeNow ?? Date() })
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: TaskItem.self, Habit.self, HabitLog.self,
                                        FocusSession.self, BlockRule.self, configurations: config)
        context = ModelContext(container)
        sessionRepo = SessionRepository(context: context)
        taskRepo = TaskRepository(context: context)
        vm = FocusViewModel(engine: engine, sessionRepo: sessionRepo, taskRepo: taskRepo)
    }

    private func advance(_ seconds: TimeInterval) {
        fakeNow = fakeNow.addingTimeInterval(seconds)
        engine.tick()
    }

    private func completedSessions() -> [FocusSession] {
        (try? context.fetch(FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.status == "completed" }))) ?? []
    }

    func testPomodoroFocusSegmentCompletesAtBreak() {
        engine.startPomodoro()
        advance(1500)
        XCTAssertEqual(completedSessions().count, 1)
    }

    func testPauseTimeNotCreditedToTask() {
        let task = taskRepo.add(title: "Deep work")
        vm.selectedTaskID = task.id
        engine.startPomodoro()
        advance(600)
        engine.pause()
        advance(300)
        engine.resume()
        advance(900)
        XCTAssertEqual(completedSessions().count, 1)
        XCTAssertEqual(task.accumulatedSeconds, 1500, accuracy: 0.01)
    }

    func testAbandonDuringFocusSettlesAbandoned() {
        engine.startPomodoro()
        advance(100)
        engine.abandon()
        let abandoned = (try? context.fetch(FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.status == "abandoned" }))) ?? []
        XCTAssertEqual(abandoned.count, 1)
        XCTAssertEqual(completedSessions().count, 0)
    }
}
