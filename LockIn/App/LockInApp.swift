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

    private var menuBarTime: String {
        let s = Int(app.engine.remaining.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(app)
                .frame(minWidth: 860, minHeight: 560)
                .task {
                    app.startBlocker()
                    app.startLifecycleObservers()
                    app.checkPendingRecovery()
                }
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(app)
                .modelContainer(container)
        } label: {
            if app.engine.isSessionActive {
                Text(menuBarTime)
            } else {
                Image(systemName: "lock.circle")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(app)
                .modelContainer(container)
        }
    }
}
