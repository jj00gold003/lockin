import SwiftUI
import SwiftData
import AppKit

/// Spec 4.3: confirm before quitting while a focus session is active, so a
/// regular quit never silently ends a running session.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let app = AppModel.shared, app.engine.isSessionActive else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = String(localized: "quit.confirm.title")
        alert.informativeText = String(localized: "quit.confirm.subtitle")
        alert.addButton(withTitle: String(localized: "quit.confirm.quit"))
        alert.addButton(withTitle: String(localized: "common.cancel"))
        if let window = NSApp.mainWindow {
            alert.beginSheetModal(for: window) { response in
                NSApp.reply(toApplicationShouldTerminate: response == .alertFirstButtonReturn)
            }
            return .terminateLater
        }
        // No key window (e.g. main window closed, menu-bar-only use): sheeting
        // on a throwaway NSWindow() is unsupported, so run a synchronous modal
        // on the main thread and reply directly.
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct LockInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
