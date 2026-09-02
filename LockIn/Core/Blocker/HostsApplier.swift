import Foundation

/// Applies built /etc/hosts content using a single administrator-authorized
/// shell step. The content is written to a temp file unprivileged; the
/// privileged script only ever receives literal, quoted paths — user domains
/// never touch the shell (they live inside the content file).
struct HostsApplier {

    /// Injectable privileged runner so tests never trigger a password prompt.
    /// The default runs the script via AppleScript's admin-authorized shell
    /// and returns whether it succeeded (user denial counts as failure).
    var runPrivileged: (String) -> Bool = { script in
        let appleScript = NSAppleScript(
            source: "do shell script \"\(script)\" with administrator privileges")
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        return error == nil
    }

    /// Writes newContent to a temp file (no privileges), then — via ONE admin
    /// prompt — re-owns it, moves it into place, and flushes the DNS cache.
    /// Never touches /etc/hosts outside the marker contract enforced by
    /// HostsContentBuilder. Returns false when the prompt is denied or fails.
    @discardableResult
    func apply(newContent: String) -> Bool {
        let tmpPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("lockin-hosts.new")

        do {
            try newContent.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            // 0600 while it holds our content; the privileged step re-owns it.
            try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                  ofItemAtPath: tmpPath)
        } catch {
            return false
        }
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let script = "/usr/sbin/chown root:wheel '\(tmpPath)' && "
            + "/bin/chmod 644 '\(tmpPath)' && "
            + "/usr/bin/ditto '\(tmpPath)' /etc/hosts && "
            + "/usr/bin/dscacheutil -flushcache && "
            + "/usr/sbin/killall -HUP mDNSResponder"

        return runPrivileged(script)
    }

    /// Reads the live hosts file (world-readable, no privileges needed).
    func currentHosts() -> String {
        (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""
    }
}
