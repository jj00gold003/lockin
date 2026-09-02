import Foundation
import SwiftData

struct HabitRepository {
    let context: ModelContext

    @discardableResult
    func add(name: String, iconSymbol: String = "flame", colorName: String = "green",
             targetPerWeek: Int = 7) -> Habit {
        let habit = Habit(name: name, iconSymbol: iconSymbol, colorName: colorName, targetPerWeek: targetPerWeek)
        context.insert(habit)
        try? context.save()
        return habit
    }

    func delete(_ habit: Habit) {
        let habitID = habit.id
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(predicate: #Predicate { $0.habitID == habitID }))) ?? []
        logs.forEach { context.delete($0) }
        context.delete(habit)
        try? context.save()
    }

    func habits() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func normalizedDay(_ day: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: day)
    }

    func isCheckedIn(habit: Habit, day: Date, calendar: Calendar = .current) -> Bool {
        let target = normalizedDay(day, calendar: calendar)
        let habitID = habit.id
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.habitID == habitID && $0.day == target }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor).first) != nil)
    }

    func checkIn(habit: Habit, day: Date, note: String = "", calendar: Calendar = .current) {
        guard !isCheckedIn(habit: habit, day: day, calendar: calendar) else { return }
        context.insert(HabitLog(habitID: habit.id, day: normalizedDay(day, calendar: calendar), note: note))
        try? context.save()
    }

    func uncheckIn(habit: Habit, day: Date, calendar: Calendar = .current) {
        let target = normalizedDay(day, calendar: calendar)
        let habitID = habit.id
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.habitID == habitID && $0.day == target }
        ))) ?? []
        logs.forEach { context.delete($0) }
        try? context.save()
    }

    /// Consecutive check-in days; today unchecked does not break the streak (counts back from yesterday)
    func streak(habitID: UUID, today: Date, calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: today)
        if !dayHasLog(habitID: habitID, day: cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var count = 0
        while dayHasLog(habitID: habitID, day: cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    /// Check-in counts per day for the last N days (heatmap data source), key = that day's 00:00
    func logsByDay(habitID: UUID, days: Int, today: Date, calendar: Calendar = .current) -> [Date: Int] {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: today)!)
        let logs = (try? context.fetch(FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.habitID == habitID && $0.day >= start }
        ))) ?? []
        var result: [Date: Int] = [:]
        for log in logs { result[calendar.startOfDay(for: log.day), default: 0] += 1 }
        return result
    }

    private func dayHasLog(habitID: UUID, day: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: day)
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.habitID == habitID && $0.day == target }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor).first) != nil)
    }
}
