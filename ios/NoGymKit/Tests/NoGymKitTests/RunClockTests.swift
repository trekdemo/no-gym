import XCTest
@testable import NoGymKit

final class RunClockTests: XCTestCase {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    // 10 s prep, then Work 20 / Rest 10, for 2 rounds: steps start at 10, 30, 40, 60; end at 70.
    let timeline = Timeline(template: .tabata(TabataConfig()), rounds: 2, prepSeconds: 10)

    func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    func testTimelineStarts() {
        XCTAssertEqual(timeline.steps.map(\.start), [10, 30, 40, 60])
        XCTAssertEqual(timeline.duration, 70)
        XCTAssertEqual(timeline.steps.map(\.round), [1, 1, 2, 2])
        XCTAssertTrue(timeline.isLastInRound(1))
        XCTAssertFalse(timeline.isLastInRound(2))
    }

    func testPositionThroughTheRun() {
        let clock = RunClock(startedAt: start)
        XCTAssertEqual(clock.position(in: timeline, at: at(0)).phase, .prep)
        XCTAssertEqual(clock.position(in: timeline, at: at(4.2)).displaySeconds, 6)

        let work = clock.position(in: timeline, at: at(15))
        XCTAssertEqual(work.phase, .active)
        XCTAssertEqual(work.stepIndex, 0)
        XCTAssertEqual(work.remaining, 15, accuracy: 0.0001)
        XCTAssertEqual(work.fraction, 0.25, accuracy: 0.0001)

        XCTAssertEqual(clock.position(in: timeline, at: at(30)).stepIndex, 1) // a boundary belongs to the next step
        XCTAssertEqual(clock.position(in: timeline, at: at(69.9)).stepIndex, 3)
        XCTAssertEqual(clock.position(in: timeline, at: at(70)).phase, .done)
    }

    func testPauseStopsTheClock() {
        var clock = RunClock(startedAt: start)
        clock.pause(at: at(12))
        XCTAssertTrue(clock.isPaused)
        XCTAssertEqual(clock.elapsed(at: at(500)), 12, accuracy: 0.0001)
        clock.resume(at: at(100))
        XCTAssertEqual(clock.elapsed(at: at(103)), 15, accuracy: 0.0001)
        // Pausing twice keeps the first pause time.
        clock.pause(at: at(110))
        clock.pause(at: at(120))
        clock.resume(at: at(130))
        XCTAssertEqual(clock.elapsed(at: at(130)), 22, accuracy: 0.0001)
    }

    func testSkipForwardAndBackward() {
        var clock = RunClock(startedAt: start)
        clock.skipForward(in: timeline, at: at(3)) // prep → first step
        XCTAssertEqual(clock.elapsed(at: at(3)), 10, accuracy: 0.0001)
        clock.skipForward(in: timeline, at: at(3))
        XCTAssertEqual(clock.position(in: timeline, at: at(3)).stepIndex, 1)

        // 1 s into step 1: back goes to step 0.
        clock.skipBackward(in: timeline, at: at(4))
        XCTAssertEqual(clock.elapsed(at: at(4)), 10, accuracy: 0.0001)

        // 5 s into step 0: back restarts step 0.
        clock.skipBackward(in: timeline, at: at(9))
        XCTAssertEqual(clock.elapsed(at: at(9)), 10, accuracy: 0.0001)

        // Back from the first step's start goes to prep.
        clock.skipBackward(in: timeline, at: at(9))
        XCTAssertEqual(clock.position(in: timeline, at: at(9)).phase, .prep)
    }

    func testSkipForwardOnLastStepFinishes() {
        var clock = RunClock(startedAt: start)
        clock.jump(to: 65, at: at(0))
        clock.skipForward(in: timeline, at: at(0))
        XCTAssertEqual(clock.position(in: timeline, at: at(0)).phase, .done)
    }

    func testSkipWhilePausedStaysPaused() {
        var clock = RunClock(startedAt: start)
        clock.pause(at: at(15))
        clock.skipForward(in: timeline, at: at(20))
        XCTAssertEqual(clock.elapsed(at: at(50)), 30, accuracy: 0.0001)
    }
}

final class BreathScaleTests: XCTestCase {
    func testCircleFollowsTheBreath() {
        let box = Timeline(template: .breathing(.box), rounds: 1, prepSeconds: 0) // inhale, hold, exhale, hold
        XCTAssertEqual(box.breathScale(stepIndex: 0, fraction: 0), 0.45, accuracy: 0.0001)
        XCTAssertEqual(box.breathScale(stepIndex: 0, fraction: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(box.breathScale(stepIndex: 1, fraction: 0.5), 1, accuracy: 0.0001)
        XCTAssertEqual(box.breathScale(stepIndex: 2, fraction: 1), 0.45, accuracy: 0.0001)
        XCTAssertEqual(box.breathScale(stepIndex: 3, fraction: 0.5), 0.45, accuracy: 0.0001)
        XCTAssertEqual(box.breathScale(stepIndex: -1, fraction: 0.5), 0.45, accuracy: 0.0001)
    }
}
