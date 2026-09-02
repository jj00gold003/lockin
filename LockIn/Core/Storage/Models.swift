import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var priority: Int = 1
    var dueDate: Date?
    var estimatedPomodoros: Int = 0
    var accumulatedSeconds: TimeInterval = 0
    var isCompleted: Bool = false
    var createdAt: Date = Date.now
    var completedAt: Date?

    init(title: String, notes: String = "", priority: Int = 1,
         dueDate: Date? = nil, estimatedPomodoros: Int = 0) {
        self.id = UUID(); self.title = title; self.notes = notes
        self.priority = priority; self.dueDate = dueDate
        self.estimatedPomodoros = estimatedPomodoros
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var iconSymbol: String = "flame"
    var colorName: String = "green"
    var targetPerWeek: Int = 7
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    init(name: String, iconSymbol: String = "flame", colorName: String = "green", targetPerWeek: Int = 7) {
        self.id = UUID(); self.name = name; self.iconSymbol = iconSymbol
        self.colorName = colorName; self.targetPerWeek = targetPerWeek
    }
}

@Model
final class HabitLog {
    var id: UUID = UUID()
    var habitID: UUID = UUID()
    var day: Date = Date.now
    var note: String = ""

    init(habitID: UUID, day: Date, note: String = "") {
        self.id = UUID(); self.habitID = habitID; self.day = day; self.note = note
    }
}

@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var type: String = "pomodoro"          // "free" | "pomodoro" | "countdown"
    var status: String = "running"         // "running" | "completed" | "abandoned"
    var taskID: UUID?
    var interruptionCount: Int = 0
    var blockCount: Int = 0

    init(type: String, taskID: UUID?, startedAt: Date = .now) {
        self.id = UUID(); self.type = type; self.taskID = taskID; self.startedAt = startedAt
    }
}

@Model
final class BlockRule {
    var id: UUID = UUID()
    var bundleID: String = ""
    var appDisplayName: String = ""
    var level: String = "soft"             // "soft" | "hard"
    var scope: String = "always"           // "always" | "sessionOnly" | "scheduled"
    var scheduleJSON: String = "[]"
    var isEnabled: Bool = true

    init(bundleID: String, appDisplayName: String, level: String = "soft",
         scope: String = "always", scheduleJSON: String = "[]", isEnabled: Bool = true) {
        self.id = UUID(); self.bundleID = bundleID; self.appDisplayName = appDisplayName
        self.level = level; self.scope = scope; self.scheduleJSON = scheduleJSON
        self.isEnabled = isEnabled
    }
}

@Model
final class WebsiteRule {
    var id: UUID = UUID()
    var domain: String = ""
    var isEnabled: Bool = true
    var createdAt: Date = Date.now

    init(domain: String, isEnabled: Bool = true) {
        self.id = UUID(); self.domain = domain; self.isEnabled = isEnabled
        self.createdAt = Date.now
    }
}
