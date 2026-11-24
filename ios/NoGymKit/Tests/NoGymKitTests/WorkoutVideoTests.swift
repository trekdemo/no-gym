import XCTest
@testable import NoGymKit

final class WorkoutVideoTests: XCTestCase {
    func testClampKeepsSegmentInsideVideoAndLongEnough() {
        XCTAssertEqual(VideoSegment(start: -2, end: 3).clamped(to: 10), VideoSegment(start: 0, end: 3))
        XCTAssertEqual(VideoSegment(start: 8, end: 14).clamped(to: 10), VideoSegment(start: 8, end: 10))
        XCTAssertEqual(VideoSegment(start: 4, end: 4.1).clamped(to: 10), VideoSegment(start: 4, end: 4.5))
        XCTAssertEqual(VideoSegment(start: 10, end: 10).clamped(to: 10), VideoSegment(start: 9.5, end: 10))
        XCTAssertEqual(VideoSegment(start: 0, end: 1).clamped(to: 0.3), VideoSegment(start: 0, end: 0.3))
    }

    func testStarterIsFiveSecondsOrWhatIsLeft() {
        XCTAssertEqual(VideoSegment.starter(at: 2, duration: 60), VideoSegment(start: 2, end: 7))
        XCTAssertEqual(VideoSegment.starter(at: 58, duration: 60), VideoSegment(start: 58, end: 60))
    }

    func testSegmentsAreSharedByLabelIgnoringCaseAndSpaces() {
        var video = WorkoutVideo(fileName: "a.mov", duration: 30)
        video.setSegment(VideoSegment(start: 1, end: 4), for: " Push-ups ")
        XCTAssertEqual(video.segment(for: "push-ups"), VideoSegment(start: 1, end: 4))
        XCTAssertEqual(video.segment(for: "PUSH-UPS"), VideoSegment(start: 1, end: 4))
        XCTAssertNil(video.segment(for: "Squats"))
        video.setSegment(nil, for: "Push-ups")
        XCTAssertNil(video.segment(for: "push-ups"))
    }

    func testSetSegmentClampsToVideo() {
        var video = WorkoutVideo(fileName: "a.mov", duration: 10)
        video.setSegment(VideoSegment(start: 8, end: 20), for: "Squats")
        XCTAssertEqual(video.segment(for: "Squats"), VideoSegment(start: 8, end: 10))
    }

    func testRemoveSegmentsExceptKeepsOnlyListedExercises() {
        var video = WorkoutVideo(fileName: "a.mov", duration: 30)
        video.setSegment(VideoSegment(start: 0, end: 2), for: "Squats")
        video.setSegment(VideoSegment(start: 2, end: 4), for: "Lunges")
        video.removeSegments(except: ["squats"])
        XCTAssertEqual(Array(video.segments.keys), ["squats"])
    }

    func testExerciseLabelsAreUniqueAndIncludeLaterTabataRounds() {
        let template = Template.tabata(TabataConfig(exercises: ["Squats", "Push-ups"]))
        let timeline = Timeline(template: template, rounds: 4, prepSeconds: 0)
        XCTAssertEqual(timeline.exerciseLabels, ["Squats", "Rest", "Push-ups"])

        let emom = Template.emom(EmomConfig(exercises: [
            Exercise(name: "Squats"), Exercise(name: "squats "), Exercise(name: " "),
        ]))
        XCTAssertEqual(Timeline(template: emom, rounds: 2, prepSeconds: 0).exerciseLabels, ["Squats"])
    }

    func testVideoSegmentAtPositionUsesFirstStepDuringPrep() {
        var video = WorkoutVideo(fileName: "a.mov", duration: 30)
        video.setSegment(VideoSegment(start: 1, end: 3), for: "Squats")
        let routine = Routine(title: "T", template: .tabata(TabataConfig(exercises: ["Squats"])),
                              rounds: 2, prepSeconds: 10, video: video)
        let timeline = routine.timeline
        let squats = VideoSegment(start: 1, end: 3)

        func position(_ elapsed: TimeInterval) -> RunPosition {
            RunClock(startedAt: Date(timeIntervalSince1970: 0))
                .position(in: timeline, at: Date(timeIntervalSince1970: elapsed))
        }
        XCTAssertEqual(routine.videoSegment(at: position(2), in: timeline), squats)   // prep
        XCTAssertEqual(routine.videoSegment(at: position(12), in: timeline), squats)  // work
        XCTAssertNil(routine.videoSegment(at: position(32), in: timeline))            // rest: none set
        XCTAssertEqual(routine.videoSegment(at: position(42), in: timeline), squats)  // round 2
        XCTAssertNil(routine.videoSegment(at: position(500), in: timeline))           // done
    }

    func testNoVideoMeansNoSegment() {
        let routine = Routine(title: "T", template: .tabata(TabataConfig()), rounds: 1)
        let position = RunClock(startedAt: .now).position(in: routine.timeline, at: .now)
        XCTAssertNil(routine.videoSegment(at: position, in: routine.timeline))
    }

    func testOldSavedRoutineWithoutVideoStillDecodes() throws {
        let routine = Routine(title: "T", template: .tabata(TabataConfig()), rounds: 1)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(routine)) as? [String: Any])
        object.removeValue(forKey: "video")
        let decoded = try JSONDecoder().decode(Routine.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.video)
        XCTAssertEqual(decoded.title, "T")
    }

    func testVideoRoundTripsThroughJSON() throws {
        var video = WorkoutVideo(fileName: "a.mov", duration: 30)
        video.setSegment(VideoSegment(start: 1.5, end: 4), for: "Squats")
        let routine = Routine(title: "T", template: .tabata(TabataConfig()), rounds: 1, video: video)
        let decoded = try JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(routine))
        XCTAssertEqual(decoded.video, video)
    }

    func testTimecodeShowsTenths() {
        XCTAssertEqual(Format.timecode(0), "0:00.0")
        XCTAssertEqual(Format.timecode(12.44), "0:12.4")
        XCTAssertEqual(Format.timecode(75.06), "1:15.1")
        XCTAssertEqual(Format.timecode(59.96), "1:00.0")
    }
}
