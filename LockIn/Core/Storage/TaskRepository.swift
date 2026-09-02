import Foundation
import SwiftData

struct TaskRepository {
    let context: ModelContext

    @discardableResult
    func add(title: String, notes: String = "", priority: Int = 1,
             dueDate: Date? = nil, estimatedPomodoros: Int = 0) -> TaskItem {
        let item = TaskItem(title: title, notes: notes, priority: priority,
                            dueDate: dueDate, estimatedPomodoros: estimatedPomodoros)
        context.insert(item)
        SaveLogger.save(context)
        return item
    }

    func toggleComplete(_ item: TaskItem) {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? .now : nil
        SaveLogger.save(context)
    }

    func delete(_ item: TaskItem) {
        context.delete(item)
        SaveLogger.save(context)
    }

    func pendingTasks() -> [TaskItem] {
        // Note: SortDescriptor(\.isCompleted) does not compile (Bool is not Comparable),
        // and pendingTasks() must exclude completed tasks (see RepositoriesTests).
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func addFocusSeconds(_ seconds: TimeInterval, to taskID: UUID) {
        guard let item = find(id: taskID) else { return }
        item.accumulatedSeconds += seconds
        SaveLogger.save(context)
    }

    private func find(id: UUID) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
