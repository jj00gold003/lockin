import XCTest
@testable import LockIn

/// The privileged runner is injected, so these tests exercise apply() without
/// ever running the admin script or touching the real /etc/hosts.
final class HostsApplierTests: XCTestCase {

    func testApplyReturnsRunnerOutcomeAndCleansUpTempFile() {
        var applier = HostsApplier()
        var receivedScript: String?
        applier.runPrivileged = { script in
            receivedScript = script
            return true
        }

        XCTAssertTrue(applier.apply(newContent: "0.0.0.0 example.com\n"))

        let script = try! XCTUnwrap(receivedScript)
        for tool in ["/usr/sbin/chown", "/bin/chmod", "/usr/bin/ditto",
                     "/usr/bin/dscacheutil", "/usr/sbin/killall"] {
            XCTAssertTrue(script.contains(tool), "missing \(tool)")
        }
        // Domains never enter the shell command — only the quoted temp path.
        XCTAssertFalse(script.contains("example.com"))
        XCTAssertTrue(script.contains("/etc/hosts"))

        // Temp file is removed afterwards.
        let leftovers = (try? FileManager.default.contentsOfDirectory(
            atPath: NSTemporaryDirectory()))?.filter { $0.hasPrefix("lockin-hosts") } ?? []
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testApplyReturnsFalseWhenRunnerFails() {
        var applier = HostsApplier()
        applier.runPrivileged = { _ in false }
        XCTAssertFalse(applier.apply(newContent: "0.0.0.0 example.com\n"))
    }
}
