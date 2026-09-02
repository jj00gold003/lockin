import Foundation
import SwiftData

// Placeholder SwiftData models so the app entry point can build.
// The data-layer task replaces these with the real definitions.

@Model
final class TaskItem {
    var title: String = ""
    var createdAt: Date = Date()

    init(title: String, createdAt: Date = Date()) {
        self.title = title
        self.createdAt = createdAt
    }
}

@Model
final class Habit {
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class HabitLog {
    var date: Date = Date()

    init(date: Date = Date()) {
        self.date = date
    }
}

@Model
final class FocusSession {
    var startedAt: Date = Date()
    var duration: TimeInterval = 0

    init(startedAt: Date = Date(), duration: TimeInterval = 0) {
        self.startedAt = startedAt
        self.duration = duration
    }
}

@Model
final class BlockRule {
    var name: String = ""
    var createdAt: Date = Date()

    init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }
}
