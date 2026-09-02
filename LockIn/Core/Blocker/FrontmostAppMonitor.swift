import AppKit
import Combine

@MainActor
final class FrontmostAppMonitor: ObservableObject {
    @Published private(set) var frontmostBundleID: String?
    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        })
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func refresh() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
