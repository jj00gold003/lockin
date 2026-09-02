import AppKit
import SwiftUI

/// Covers each on-screen window of a blocked app with a small non-activating
/// panel (replaces the old full-screen overlay, which covered the entire
/// display instead of the app's own windows).
@MainActor
final class WindowCoverController {
    private var panels: [Int: NSPanel] = [:] // CGWindowNumber -> cover panel
    private var refreshTimer: Timer?
    private var targetPID: pid_t?
    private var engine: TimerEngine?
    private var blocker: BlockerController?
    private var appName: String = ""

    func showCovers(for app: NSRunningApplication,
                    engine: TimerEngine,
                    blocker: BlockerController) {
        targetPID = app.processIdentifier
        self.engine = engine
        self.blocker = blocker
        appName = app.localizedName ?? app.bundleIdentifier ?? ""
        if refreshTimer == nil {
            // Cheap 1s refresh: recompute the window list so covers track
            // windows opening, closing, or moving. No faster than 1s.
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
        refresh()
    }

    func hideAll() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        targetPID = nil
        engine = nil
        blocker = nil
    }

    // MARK: - Refresh

    private func refresh() {
        guard let targetPID, let engine, let blocker else {
            hideAll()
            return
        }
        var boundsByWindow: [Int: CGRect] = [:]
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] ?? []
        for info in list {
            guard info[kCGWindowOwnerPID as String] as? Int32 == targetPID,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let number = info[kCGWindowNumber as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 0, bounds.height > 0
            else { continue }
            boundsByWindow[number] = bounds
        }

        // Remove covers for windows that disappeared.
        for (number, panel) in panels where boundsByWindow[number] == nil {
            panel.orderOut(nil)
            panels.removeValue(forKey: number)
        }
        // Add covers for new windows and reposition existing ones.
        for (number, bounds) in boundsByWindow {
            let panel = panels[number] ?? makePanel(engine: engine, blocker: blocker)
            panels[number] = panel
            panel.setFrame(screenFrame(forCGBounds: bounds), display: true)
            panel.orderFrontRegardless()
        }
    }

    private func makePanel(engine: TimerEngine, blocker: BlockerController) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        // Accept mouse events so clicks hit the cover instead of the app below.
        panel.ignoresMouseEvents = false
        panel.contentView = NSHostingView(
            rootView: BlockCoverView(engine: engine, appName: appName)
        )
        return panel
    }

    // MARK: - Coordinate conversion

    /// CG window coordinates use a top-left origin (y grows downward) while
    /// NSScreen uses a bottom-left origin for the same global virtual space
    /// (x is shared). The conversion is therefore
    /// `nsY = primaryScreenHeight - cgY - height`, using the primary screen
    /// (the one whose frame origin is .zero) as the height reference.
    private func screenFrame(forCGBounds bounds: CGRect) -> CGRect {
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero }
        let primaryHeight = primaryScreen?.frame.height ?? NSScreen.main?.frame.height ?? 0
        return CGRect(
            x: bounds.origin.x,
            y: primaryHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }
}
