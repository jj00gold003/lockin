import AppKit
import SwiftUI

/// Small always-on-top banner at the bottom-center of the main screen,
/// shown for 3 seconds on every block event (the same panel is reused and
/// the 3s timer restarts on each show).
@MainActor
final class BannerController {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(appName: String) {
        let panel = ensurePanel()
        let text = String(format: NSLocalizedString("block.banner.text", comment: ""), appName)
        let hosting = NSHostingView(rootView: BannerView(text: text))
        panel.contentView = hosting
        let size = hosting.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CGRect(
            x: visible.midX - size.width / 2,
            y: visible.minY + 12,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        restartHideTimer()
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Informational only: never intercept clicks meant for other apps.
        panel.ignoresMouseEvents = true
        self.panel = panel
        return panel
    }

    private func restartHideTimer() {
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.panel?.orderOut(nil) }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }
}

private struct BannerView: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Theme.accent(for: .focus))
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Color.black.opacity(0.15)))
    }
}
