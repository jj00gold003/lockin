import XCTest
import SwiftData
@testable import LockIn

final class RepositoriesTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: TaskItem.self, Habit.self, HabitLog.self,
            FocusSession.self, BlockRule.self, configurations: config
        )
        context = ModelContext(container)
    }

    // MARK: TaskRepository

    func testAddFocusSecondsAccumulates() {
        let tasks = TaskRepository(context: context)
        let task = tasks.add(title: "Refactor module")
        tasks.addFocusSeconds(1500, to: task.id)
        tasks.addFocusSeconds(300, to: task.id)
        XCTAssertEqual(tasks.pendingTasks().first?.accumulatedSeconds, 1800)
    }

    func testToggleCompleteSetsCompletedAt() {
        let tasks = TaskRepository(context: context)
        let task = tasks.add(title: "Email")
        tasks.toggleComplete(task)
        let done = tasks.pendingTasks()
        XCTAssertTrue(done.isEmpty || done.allSatisfy { $0.id != task.id })
    }

    // MARK: SessionRepository

    func testSessionLifecycleAndIncompleteRecovery() {
        let sessions = SessionRepository(context: context)
        let s = sessions.start(type: "pomodoro", taskID: nil, at: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertEqual(sessions.incomplete().count, 1)
        sessions.finish(id: s.id, status: "completed", interruptions: 2, at: Date(timeIntervalSince1970: 1_000_000 + 1500))
        XCTAssertEqual(sessions.incomplete().count, 0)
        XCTAssertEqual(sessions.focusSeconds(since: .distantPast), 1500)
    }

    func testFocusSecondsByDayBuckets() {
        let sessions = SessionRepository(context: context)
        let now = Date()
        let s = sessions.start(type: "free", taskID: nil, at: now.addingTimeInterval(-600))
        sessions.finish(id: s.id, status: "completed", interruptions: 0, at: now)
        let buckets = sessions.focusSecondsByDay(days: 7)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.last?.seconds ?? 0, 600, accuracy: 5)
    }

    // MARK: HabitRepository

    func testCheckInAndStreak() {
        let habits = HabitRepository(context: context)
        let habit = habits.add(name: "Reading", targetPerWeek: 5)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        habits.checkIn(habit: habit, day: today)
        habits.checkIn(habit: habit, day: cal.date(byAdding: .day, value: -1, to: today)!)
        habits.checkIn(habit: habit, day: cal.date(byAdding: .day, value: -2, to: today)!)
        XCTAssertTrue(habits.isCheckedIn(habit: habit, day: today))
        XCTAssertEqual(habits.streak(habitID: habit.id, today: today), 3)
        habits.uncheckIn(habit: habit, day: today)
        // Today unchecked but yesterday checked; streak does not break (counts back from yesterday)
        XCTAssertEqual(habits.streak(habitID: habit.id, today: today), 2)
    }

    func testDuplicateCheckInIsIdempotent() {
        let habits = HabitRepository(context: context)
        let habit = habits.add(name: "Exercise")
        let today = Calendar.current.startOfDay(for: .now)
        habits.checkIn(habit: habit, day: today)
        habits.checkIn(habit: habit, day: today)
        XCTAssertEqual(habits.logsByDay(habitID: habit.id, days: 7, today: today)[today], 1)
    }

    // MARK: BlockRuleRepository

    func testBlockRuleCRUD() {
        let rules = BlockRuleRepository(context: context)
        let rule = rules.add(bundleID: "com.reddit.desktop", appDisplayName: "Reddit", level: "hard")
        XCTAssertEqual(rules.all().count, 1)
        rules.setEnabled(rule, to: false)
        XCTAssertEqual(rules.all().first?.isEnabled, false)
        rules.delete(rule)
        XCTAssertEqual(rules.all().count, 0)
    }
}
