import XCTest
@testable import LockIn

@MainActor
final class TimerEngineTests: XCTestCase {
    private var fakeNow: Date!
    private var engine: TimerEngine!

    override func setUp() {
        fakeNow = Date(timeIntervalSince1970: 1_700_000_000)
        engine = TimerEngine(now: { [weak self] in self?.fakeNow ?? Date() })
    }

    private func advance(_ seconds: TimeInterval) {
        fakeNow = fakeNow.addingTimeInterval(seconds)
        engine.tick()
    }

    func testAnchorBasedRemaining() {
        engine.startPomodoro()
        XCTAssertEqual(engine.remaining, 1500, accuracy: 0.01)
        advance(60)
        XCTAssertEqual(engine.remaining, 1440, accuracy: 0.01)
        XCTAssertEqual(engine.phase, .focusing)
    }

    func testPauseIncrementsInterruptionAndFreezes() {
        engine.startPomodoro()
        advance(120)
        engine.pause()
        XCTAssertEqual(engine.interruptionCount, 1)
        XCTAssertEqual(engine.phase, .paused)
        advance(500) // time flows while paused; remaining must not change
        XCTAssertEqual(engine.remaining, 1380, accuracy: 0.01)
    }

    func testResumeRecoversRemaining() {
        engine.startPomodoro()
        advance(120)
        engine.pause()
        engine.resume()
        XCTAssertEqual(engine.phase, .focusing)
        advance(30)
        XCTAssertEqual(engine.remaining, 1350, accuracy: 0.01)
    }

    func testFocusEndGoesToShortBreak() {
        engine.startPomodoro()
        advance(1500)
        XCTAssertEqual(engine.phase, .resting)
        XCTAssertEqual(engine.remaining, 300, accuracy: 0.01)
    }

    func testFourthRoundUsesLongBreak() {
        engine.startPomodoro()
        for _ in 0..<3 {
            advance(1500) // focus
            advance(300)  // short break
        }
        XCTAssertEqual(engine.round, 4)
        advance(1500)
        XCTAssertEqual(engine.phase, .resting)
        XCTAssertEqual(engine.remaining, 900, accuracy: 0.01) // long break
    }

    func testBreakEndStartsNextRound() {
        engine.startPomodoro()
        advance(1500)
        advance(300)
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.round, 2)
    }

    func testSkipBreak() {
        engine.startPomodoro()
        advance(1500)
        engine.skipBreak()
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.round, 2)
    }

    func testAbandonSetsFinishedAndReason() {
        engine.startPomodoro()
        advance(100)
        engine.abandon()
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.lastEndReason, .abandoned)
        XCTAssertFalse(engine.isSessionActive)
    }

    func testFreeFocusGrowsElapsed() {
        engine.startFreeFocus()
        advance(3600)
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.elapsed, 3600, accuracy: 0.01)
        XCTAssertEqual(engine.mode, .free)
    }

    func testSleepDuringLongBreakAdvancesRound() {
        engine.startPomodoro()
        advance(1500)          // enter break
        engine.handleSleep()
        advance(400)           // slept 400s > 300s break duration
        engine.handleWake()
        XCTAssertEqual(engine.phase, .focusing)
        XCTAssertEqual(engine.round, 2)
    }
}
