import SwiftUI
import SwiftData

@main
struct LockInApp: App {
    let container: ModelContainer
    @StateObject private var app: AppModel

    init() {
        do {
            // Local constant: StateObject(wrappedValue:) is an escaping autoclosure
            // and cannot capture self.container before full initialization.
            let made = try ModelContainer(
                for: TaskItem.self, Habit.self, HabitLog.self,
                FocusSession.self, BlockRule.self
            )
            container = made
            _app = StateObject(wrappedValue: AppModel(container: made))
        } catch {
            fatalError("LockIn failed to create local database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(app)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
