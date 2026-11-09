import XCTest
@testable import NoGymKit

final class FormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(Format.clock(0), "0:00")
        XCTAssertEqual(Format.clock(4.2), "0:05")
        XCTAssertEqual(Format.clock(240), "4:00")
        XCTAssertEqual(Format.clock(3723), "1:02:03")
    }

    func testDuration() {
        XCTAssertEqual(Format.duration(20), "20 s")
        XCTAssertEqual(Format.duration(5.5), "5.5 s")
        XCTAssertEqual(Format.duration(60), "1 min")
        XCTAssertEqual(Format.duration(90), "1 min 30 s")
    }

    func testSummary() {
        let routine = Routine(title: "T", template: .tabata(TabataConfig()), rounds: 8)
        XCTAssertEqual(Format.summary(routine), "8 rounds · 4:00")
    }

    func testParseExercises() {
        let parsed = Format.parseExercises("Min 1: 10 Deadlifts\nmin 2 - 12x Sit-Ups\n\n  Minute 3: REST\n5 × Burpees\n")
        XCTAssertEqual(parsed.map(\.name), ["Deadlifts", "Sit-Ups", "REST", "Burpees"])
        XCTAssertEqual(parsed.map(\.reps), [10, 12, nil, 5])
    }

    func testFormatRoundTrip() {
        let exercises = [Exercise(name: "Deadlifts", reps: 10), Exercise(name: "REST")]
        let text = Format.formatExercises(exercises)
        XCTAssertEqual(text, "10 Deadlifts\nREST\n")
        let back = Format.parseExercises(text)
        XCTAssertEqual(back.map(\.name), exercises.map(\.name))
        XCTAssertEqual(back.map(\.reps), exercises.map(\.reps))
    }
}

final class ToneSynthTests: XCTestCase {
    func testEverySoundIsAudibleAndInRange() {
        for choice in SoundChoice.allCases where choice != .off {
            let samples = ToneSynth.samples(for: choice)
            XCTAssertFalse(samples.isEmpty, choice.title)
            let peak = samples.map(abs).max() ?? 0
            XCTAssertGreaterThan(peak, 0.1, choice.title)
            XCTAssertLessThanOrEqual(peak, 1, choice.title)
            // Starts and ends silent, so there is no click.
            XCTAssertLessThan(abs(samples.first!), 0.01, choice.title)
            XCTAssertLessThan(abs(samples.last!), 0.01, choice.title)
        }
        XCTAssertTrue(ToneSynth.samples(for: .off).isEmpty)
    }

    func testBreathToneLastsThePhase() {
        let rate = 8_000.0
        XCTAssertEqual(ToneSynth.breath(.inhale, duration: 4, sampleRate: rate).count, 32_000)
        XCTAssertEqual(ToneSynth.breath(.exhale, duration: 5.5, sampleRate: rate).count, 44_000)
        XCTAssertLessThanOrEqual(ToneSynth.breath(.hold, duration: 7, sampleRate: rate).count, 6_400)
        XCTAssertTrue(ToneSynth.breath(.work, duration: 4, sampleRate: rate).isEmpty)
    }

    func testCountdownTickIsShort() {
        XCTAssertEqual(ToneSynth.countdownTick(sampleRate: 1_000).count, 150)
    }
}
