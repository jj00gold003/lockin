import AppKit
import ApplicationServices

/// Static utility for the Accessibility (AX) permission and hard-block minimize.
enum AccessibilityGuard {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system authorization dialog; returns whether AX is currently granted.
    @discardableResult
    static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Minimizes the target app (hard block); returns false on failure (caller degrades to soft block).
    static func minimize(app: NSRunningApplication) -> Bool {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        return result == .success
    }
}
