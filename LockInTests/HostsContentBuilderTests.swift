import XCTest
@testable import LockIn

/// Pure tests for the /etc/hosts managed-section builder. No container, no
/// privileged access: these prove the safety-critical content contract only.
final class HostsContentBuilderTests: XCTestCase {

    private var markersBlockEmpty: String {
        "\(HostsMarkers.begin)\n\(HostsMarkers.end)\n"
    }

    // MARK: - No markers present (append mode)

    func testAppendWhenNoMarkers() {
        let current = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"
        let out = HostsContentBuilder.build(currentHosts: current,
                                            enabledDomains: ["youtube.com"])
        XCTAssertTrue(out.hasPrefix(current))
        XCTAssertTrue(out.contains("\(HostsMarkers.begin)\n0.0.0.0 youtube.com\n0.0.0.0 www.youtube.com\n\(HostsMarkers.end)\n"))
        // Separating newline exists, and no runaway blank lines.
        XCTAssertFalse(out.contains("\n\n\n"))
    }

    func testAppendAddsSeparatingNewlineWhenMissingTrailingNewline() {
        let current = "127.0.0.1 localhost" // no trailing newline
        let out = HostsContentBuilder.build(currentHosts: current,
                                            enabledDomains: ["x.com"])
        XCTAssertTrue(out.hasPrefix("127.0.0.1 localhost\n"))
        XCTAssertTrue(out.contains("\(HostsMarkers.begin)\n"))
    }

    // MARK: - Markers present (replace mode)

    func testReplacesOnlyManagedSectionPreservingForeignLines() {
        let before = "# user comment\n127.0.0.1 myserver.local\n"
        let after = "# after the section\n"
        let current = before + "\(HostsMarkers.begin)\n0.0.0.0 old.com\n\(HostsMarkers.end)\n" + after
        let out = HostsContentBuilder.build(currentHosts: current,
                                            enabledDomains: ["new.com"])
        XCTAssertTrue(out.hasPrefix(before))
        XCTAssertTrue(out.hasSuffix(after))
        XCTAssertTrue(out.contains("0.0.0.0 new.com"))
        XCTAssertFalse(out.contains("old.com"))
    }

    // MARK: - Idempotency (build must be identity on already-synced content)

    func testIdempotency() {
        let current = "127.0.0.1 localhost\n"
        let once = HostsContentBuilder.build(currentHosts: current,
                                             enabledDomains: ["a.com", "b.org"])
        let twice = HostsContentBuilder.build(currentHosts: once,
                                              enabledDomains: ["a.com", "b.org"])
        XCTAssertEqual(once, twice)
    }

    func testIdempotencyOnMarkersOnlyContent() {
        let current = "\(HostsMarkers.begin)\n\(HostsMarkers.end)\n"
        let out = HostsContentBuilder.build(currentHosts: current,
                                            enabledDomains: [])
        XCTAssertEqual(out, current)
    }

    // MARK: - Domain expansion and dedupe

    func testWWWVariantSkippedForWWWDomains() {
        let out = HostsContentBuilder.build(currentHosts: "",
                                            enabledDomains: ["www.reddit.com"])
        XCTAssertTrue(out.contains("0.0.0.0 www.reddit.com\n"))
        XCTAssertFalse(out.contains("0.0.0.0 www.www.reddit.com\n"))
    }

    func testDedupeCaseInsensitiveAndSorted() {
        let out = HostsContentBuilder.build(currentHosts: "",
                                            enabledDomains: ["Zebra.com", "apple.com", "APPLE.com"])
        let lines = out.components(separatedBy: "\n")
        let idxApple = lines.firstIndex(of: "0.0.0.0 apple.com")
        let idxZebra = lines.firstIndex(of: "0.0.0.0 zebra.com")
        XCTAssertNotNil(idxApple)
        XCTAssertNotNil(idxZebra)
        XCTAssertLessThan(idxApple!, idxZebra!)
        // apple.com appears exactly once
        XCTAssertEqual(lines.filter { $0 == "0.0.0.0 apple.com" }.count, 1)
    }

    func testEmptyRulesYieldMarkersOnlySection() {
        let out = HostsContentBuilder.build(currentHosts: "127.0.0.1 localhost\n",
                                            enabledDomains: [])
        XCTAssertTrue(out.hasSuffix("\(HostsMarkers.begin)\n\(HostsMarkers.end)\n"))
        XCTAssertTrue(out.hasPrefix("127.0.0.1 localhost\n"))
    }

    func testEndsWithExactlyOneNewline() {
        let out = HostsContentBuilder.build(currentHosts: "127.0.0.1 localhost\n\n\n",
                                            enabledDomains: ["a.com"])
        XCTAssertTrue(out.hasSuffix("\n"))
        XCTAssertFalse(out.hasSuffix("\n\n"))
    }

    // MARK: - Domain normalization

    func testNormalizeDomainFromURL() {
        XCTAssertEqual(HostsContentBuilder.normalizeDomain("https://www.YouTube.com/watch?v=1"),
                       "youtube.com")
    }

    func testNormalizeDomainBare() {
        XCTAssertEqual(HostsContentBuilder.normalizeDomain("Example.COM"), "example.com")
    }

    func testNormalizeDomainStripsPortAndPath() {
        XCTAssertEqual(HostsContentBuilder.normalizeDomain("http://x.com:8080/feed"), "x.com")
    }

    func testNormalizeDomainStripsTrailingDot() {
        XCTAssertEqual(HostsContentBuilder.normalizeDomain("youtube.com."), "youtube.com")
    }

    func testNormalizeDomainInvalidReturnsNil() {
        XCTAssertNil(HostsContentBuilder.normalizeDomain(""))
        XCTAssertNil(HostsContentBuilder.normalizeDomain("   "))
        XCTAssertNil(HostsContentBuilder.normalizeDomain("localhost"))
        XCTAssertNil(HostsContentBuilder.normalizeDomain("has space.com"))
        XCTAssertNil(HostsContentBuilder.normalizeDomain("https://"))
    }
}
