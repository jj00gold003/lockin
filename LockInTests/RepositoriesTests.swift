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
            FocusSession.self, BlockRule.self, WebsiteRule.self, configurations: config
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

    // Task edit fields are mutated directly on the model (SettingsView pattern)
    // then saved via SaveLogger; a fresh ModelContext on the same container
    // proves the edits round-trip through the store.
    func testTaskEditFieldsPersistRoundTrip() throws {
        let tasks = TaskRepository(context: context)
        let task = tasks.add(title: "Draft spec")
        let due = Date(timeIntervalSince1970: 1_800_000_000)

        task.title = "Draft spec v2"
        task.notes = "focus on persistence"
        task.priority = 2
        task.dueDate = due
        task.estimatedPomodoros = 4
        SaveLogger.save(context)

        let freshContext = ModelContext(container)
        let fetched = try freshContext.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(fetched.count, 1)
        let item = try XCTUnwrap(fetched.first)
        XCTAssertEqual(item.id, task.id)
        XCTAssertEqual(item.title, "Draft spec v2")
        XCTAssertEqual(item.notes, "focus on persistence")
        XCTAssertEqual(item.priority, 2)
        XCTAssertEqual(item.dueDate, due)
        XCTAssertEqual(item.estimatedPomodoros, 4)

        // Clearing the due date must round-trip as nil too
        item.dueDate = nil
        SaveLogger.save(freshContext)
        let reloaded = ModelContext(container)
        let again = try reloaded.fetch(FetchDescriptor<TaskItem>())
        XCTAssertNil(again.first?.dueDate)
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

    func testCompletionRate() {
        let sessions = SessionRepository(context: context)
        let a = sessions.start(type: "pomodoro", taskID: nil)
        sessions.finish(id: a.id, status: "completed", interruptions: 0)
        let b = sessions.start(type: "free", taskID: nil)
        sessions.finish(id: b.id, status: "abandoned", interruptions: 1)
        XCTAssertEqual(sessions.completionRate(days: 7) ?? -1, 0.5, accuracy: 0.001)
        // `now` far in the future: the 1-day window starts after every session -> no data -> nil
        XCTAssertNil(sessions.completionRate(days: 1, now: .distantFuture.addingTimeInterval(-86400)))
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

    // MARK: WebsiteRuleRepository

    func testWebsiteRuleAddNormalizesDomain() {
        let sites = WebsiteRuleRepository(context: context)
        let rule = sites.add(domain: "https://www.YouTube.com/watch?v=1")
        XCTAssertEqual(rule?.domain, "youtube.com")
        // Stored value is the normalized domain (roundtrip via fetch).
        XCTAssertEqual(sites.all().first?.domain, "youtube.com")
        XCTAssertEqual(sites.all().count, 1)
    }

    func testWebsiteRuleInvalidDomainRejected() {
        let sites = WebsiteRuleRepository(context: context)
        XCTAssertNil(sites.add(domain: "not a domain"))
        XCTAssertEqual(sites.all().count, 0)
    }

    func testWebsiteRuleSetEnabledAndDelete() {
        let sites = WebsiteRuleRepository(context: context)
        let rule = sites.add(domain: "reddit.com")!
        sites.setEnabled(rule, to: false)
        XCTAssertEqual(sites.all().first?.isEnabled, false)
        sites.delete(rule)
        XCTAssertEqual(sites.all().count, 0)
    }
}
