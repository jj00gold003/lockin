import XCTest
@testable import LockIn

final class BlockRuleEvaluatorTests: XCTestCase {
    private let evaluator = BlockRuleEvaluator()
    private let twitterID = "com.atebits.Tweetie2"

    private func rule(_ bundleID: String, level: BlockLevel, scope: BlockScope,
                      windows: [ScheduleWindow] = [], enabled: Bool = true) -> RuleSnapshot {
        RuleSnapshot(id: UUID(), bundleID: bundleID, level: level, scope: scope,
                     windows: windows, isEnabled: enabled)
    }

    /// 2026-09-03 is a Thursday (weekday = 5)
    private var thursday9am: Date {
        var comps = DateComponents(); comps.year = 2026; comps.month = 9; comps.day = 3; comps.hour = 9
        return Calendar.current.date(from: comps)!
    }

    func testNoRulesMeansAllow() {
        let d = evaluator.evaluate(rules: [], frontmostBundleID: twitterID,
                                   isSessionActive: true, date: thursday9am)
        XCTAssertEqual(d.action, .allow)
    }

    func testSessionOnlyBlocksDuringSessionOnly() {
        let rules = [rule(twitterID, level: .soft, scope: .sessionOnly)]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: true, date: thursday9am).action, .soft)
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: false, date: thursday9am).action, .allow)
    }

    func testDifferentAppIsAllowed() {
        let rules = [rule(twitterID, level: .soft, scope: .sessionOnly)]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: "com.apple.Safari",
                                          isSessionActive: true, date: thursday9am).action, .allow)
    }

    func testScheduledWindowMatches() {
        // Thursday 9:00-18:00 => 540..<1080
        let rules = [rule(twitterID, level: .hard, scope: .scheduled,
                          windows: [ScheduleWindow(weekday: 5, startMinute: 540, endMinute: 1080)])]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: false, date: thursday9am).action, .hard)
        // 18:00 exactly does not match (start inclusive, end exclusive)
        var comps = DateComponents(); comps.year = 2026; comps.month = 9; comps.day = 3; comps.hour = 18
        let sixPm = Calendar.current.date(from: comps)!
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: false, date: sixPm).action, .allow)
    }

    func testWrongWeekdayDoesNotMatch() {
        let rules = [rule(twitterID, level: .hard, scope: .scheduled,
                          windows: [ScheduleWindow(weekday: 1, startMinute: 0, endMinute: 1440)])]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: false, date: thursday9am).action, .allow)
    }

    func testHardBeatsSoft() {
        let rules = [
            rule(twitterID, level: .soft, scope: .sessionOnly),
            rule(twitterID, level: .hard, scope: .sessionOnly),
        ]
        let d = evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                   isSessionActive: true, date: thursday9am)
        XCTAssertEqual(d.action, .hard)
    }

    func testAlwaysRuleBlocksWithoutSession() {
        let rules = [rule(twitterID, level: .soft, scope: .always)]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: false, date: thursday9am).action, .soft)
    }

    func testAlwaysSoftVsSessionOnlyHardHardWins() {
        let rules = [
            rule(twitterID, level: .soft, scope: .always),
            rule(twitterID, level: .hard, scope: .sessionOnly),
        ]
        let d = evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                   isSessionActive: true, date: thursday9am)
        XCTAssertEqual(d.action, .hard)
    }

    func testDisabledRuleIgnored() {
        let rules = [rule(twitterID, level: .hard, scope: .sessionOnly, enabled: false)]
        XCTAssertEqual(evaluator.evaluate(rules: rules, frontmostBundleID: twitterID,
                                          isSessionActive: true, date: thursday9am).action, .allow)
    }
}
