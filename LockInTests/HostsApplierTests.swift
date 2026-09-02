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

    func testApplyUsesUniqueTempPathPerCall() {
        var applier = HostsApplier()
        var paths: [String] = []
        applier.runPrivileged = { script in
            // The quoted temp path is the only user-controlled component.
            paths.append(script)
            return true
        }
        XCTAssertTrue(applier.apply(newContent: "0.0.0.0 a.com\n"))
        XCTAssertTrue(applier.apply(newContent: "0.0.0.0 b.com\n"))
        XCTAssertEqual(paths.count, 2)
        XCTAssertNotEqual(paths[0], paths[1], "each apply must use a fresh temp path")
        for script in paths {
            XCTAssertTrue(script.contains("lockin-hosts-"))
        }
    }
}
