import XCTest
@testable import NoGymKit

final class CueScheduleTests: XCTestCase {
    // 10 s prep, Work 20 / Rest 10, 2 rounds. Period ends at 10, 30, 40, 60, 70.
    let timeline = Timeline(template: .tabata(TabataConfig()), rounds: 2, prepSeconds: 10)

    func boundaries(_ cues: [Cue]) -> [(TimeInterval, Boundary, SoundChoice)] {
        cues.compactMap {
            if case .boundary(let boundary, let choice) = $0.kind { return ($0.at, boundary, choice) }
            return nil
        }
    }

    func testBoundarySoundsAndPrecedence() {
        let cues = CueSchedule.cues(for: timeline, sound: SoundSettings())
        let found = boundaries(cues)
        XCTAssertEqual(found.map(\.0), [10, 30, 40, 60, 70])
        XCTAssertEqual(found.map(\.1), [.go, .interval, .round, .interval, .finish])
        XCTAssertEqual(found.map(\.2), [.beep, .beep, .doubleBeep, .beep, .bell])
    }

    func testFallbackWhenAnImportantSoundIsOff() {
        let sound = SoundSettings(roundEnd: .off, finish: .off)
        let found = boundaries(CueSchedule.cues(for: timeline, sound: sound))
        XCTAssertEqual(found.map(\.2), [.beep, .beep, .beep, .beep, .beep])

        let silent = SoundSettings(countdown: .off, intervalEnd: .off, roundEnd: .off, finish: .off)
        XCTAssertTrue(CueSchedule.cues(for: timeline, sound: silent).isEmpty)
    }

    func testCountdownTicks() {
        let cues = CueSchedule.cues(for: timeline, sound: SoundSettings(countdown: .last3))
        let ticks = cues.filter { $0.kind == .countdown }.map(\.at)
        XCTAssertEqual(ticks, [7, 8, 9, 27, 28, 29, 37, 38, 39, 57, 58, 59, 67, 68, 69])
    }

    func testNoTicksAtTheStartOfShortPeriods() {
        let short = Timeline(template: .custom([Interval(label: "A", seconds: 2)]), rounds: 1, prepSeconds: 0)
        let ticks = CueSchedule.cues(for: short, sound: SoundSettings(countdown: .last5))
            .filter { $0.kind == .countdown }.map(\.at)
        XCTAssertEqual(ticks, [1])
    }

    func testCuesAreSorted() {
        let cues = CueSchedule.cues(for: timeline, sound: SoundSettings(countdown: .last5))
        XCTAssertEqual(cues.map(\.at), cues.map(\.at).sorted())
    }

    func testBreathingGuideTones() {
        let box = Timeline(template: .breathing(.box), rounds: 2, prepSeconds: 5)
        let cues = CueSchedule.cues(for: box, sound: .defaults(for: .breathing))
        let breaths = cues.compactMap { cue -> (TimeInterval, Role)? in
            if case .breathe(let role, let duration) = cue.kind {
                XCTAssertEqual(duration, 4)
                return (cue.at, role)
            }
            return nil
        }
        XCTAssertEqual(breaths.map(\.0), [5, 9, 13, 17, 21, 25, 29, 33])
        XCTAssertEqual(breaths.map(\.1).prefix(4), [.inhale, .hold, .exhale, .hold])
        // Breathing defaults: no ticks, no step sounds, a bell at the end.
        XCTAssertFalse(cues.contains { $0.kind == .countdown })
        XCTAssertEqual(boundaries(cues).map(\.1), [.finish])
    }
}
