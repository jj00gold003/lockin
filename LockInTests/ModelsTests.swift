import XCTest
import SwiftData
@testable import LockIn

final class ModelsTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TaskItem.self, Habit.self, HabitLog.self,
            FocusSession.self, BlockRule.self, WebsiteRule.self,
            configurations: config
        )
    }

    func testTaskItemRoundtrip() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let task = TaskItem(title: "Weekly report", priority: 2, dueDate: .now, estimatedPomodoros: 3)
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Weekly report")
        XCTAssertEqual(fetched.first?.priority, 2)
        XCTAssertEqual(fetched.first?.isCompleted, false)
    }

    func testFocusSessionDefaults() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let session = FocusSession(type: "free", taskID: nil)
        context.insert(session)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<FocusSession>())
        XCTAssertEqual(fetched.first?.status, "running")
        XCTAssertNil(fetched.first?.endedAt)
    }

    func testBlockRuleDefaults() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rule = BlockRule(bundleID: "com.apple.Notes", appDisplayName: "Notes")
        context.insert(rule)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<BlockRule>())
        XCTAssertEqual(fetched.first?.level, "soft")
        XCTAssertEqual(fetched.first?.scope, "always")
        XCTAssertEqual(fetched.first?.isEnabled, true)
    }
}
