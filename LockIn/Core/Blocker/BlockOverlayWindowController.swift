import AppKit
import SwiftUI

@MainActor
final class BlockOverlayWindowController {
    private var panel: NSPanel?

    func show(engine: TimerEngine, blocker: BlockerController) {
        if panel == nil {
            let p = NSPanel(
                contentRect: NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1440, height: 900),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            p.level = .screenSaver
            p.isOpaque = true
            p.backgroundColor = .black
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.ignoresMouseEvents = false
            p.contentView = NSHostingView(rootView: BlockOverlayView()
                .environmentObject(engine)
                .environmentObject(blocker))
            panel = p
        }
        panel?.setFrame(NSScreen.main?.frame ?? panel?.frame ?? .zero, display: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
