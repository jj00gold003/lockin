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
}
