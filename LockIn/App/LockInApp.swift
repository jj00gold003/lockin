import SwiftUI
import SwiftData

@main
struct LockInApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: TaskItem.self, Habit.self, HabitLog.self,
                FocusSession.self, BlockRule.self
            )
        } catch {
            fatalError("LockIn failed to create local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
