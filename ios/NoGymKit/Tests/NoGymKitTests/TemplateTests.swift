import XCTest
@testable import NoGymKit

final class TemplateTests: XCTestCase {
    func testTabataEightRoundsIsSixteenIntervalsAndFourMinutes() {
        let routine = Routine(title: "Tabata", template: .tabata(TabataConfig()), rounds: 8)
        XCTAssertEqual(routine.timeline.steps.count, 16)
        XCTAssertEqual(routine.totalSeconds, 240)
        XCTAssertEqual(routine.timeline.duration, 250) // plus 10 s prep
        XCTAssertEqual(routine.timeline.steps.map(\.interval.role).prefix(2), [.work, .rest])
    }

    func testTabataCyclesExerciseNamesThroughRounds() {
        let template = Template.tabata(TabataConfig(exercises: ["Squats", " ", "Push-ups"]))
        let workLabels = Timeline(template: template, rounds: 4, prepSeconds: 0).steps
            .filter { $0.interval.role == .work }
            .map(\.interval.label)
        XCTAssertEqual(workLabels, ["Squats", "Push-ups", "Squats", "Push-ups"])
    }

    func testTabataWithoutRestHasOnlyWork() {
        let template = Template.tabata(TabataConfig(workSeconds: 30, restSeconds: 0))
        XCTAssertEqual(template.intervals(round: 0).map(\.label), ["Work"])
    }

    func testBreathingDropsZeroHolds() {
        let labels = Template.breathing(.relax478).intervals(round: 0).map(\.label)
        XCTAssertEqual(labels, ["Inhale", "Hold", "Exhale"])
        XCTAssertEqual(Template.breathing(.coherent).intervals(round: 0).map(\.role), [.inhale, .exhale])
        XCTAssertEqual(Template.breathing(.box).intervals(round: 0).count, 4)
    }

    func testEmomUsesStepLengthAndMarksRest() {
        let template = Template.emom(EmomConfig(stepSeconds: 60, exercises: [
            Exercise(name: "Deadlifts", reps: 10), Exercise(name: "REST"),
        ]))
        let intervals = template.intervals(round: 0)
        XCTAssertEqual(intervals.map(\.seconds), [60, 60])
        XCTAssertEqual(intervals.map(\.role), [.work, .rest])
        XCTAssertEqual(intervals[0].displayLabel, "10 × Deadlifts")
        XCTAssertEqual(intervals[1].displayLabel, "REST")
    }

    func testEveryStarterIsValid() {
        for kind in TemplateKind.allCases {
            let routine = Routine(title: kind.title, template: .starter(kind), rounds: Template.starterRounds(kind))
            XCTAssertNil(routine.validationError(), kind.title)
            XCTAssertEqual(routine.sound, SoundSettings.defaults(for: kind))
        }
    }

    func testValidation() {
        var routine = Routine(title: " ", template: .starter(.custom), rounds: 1)
        XCTAssertEqual(routine.validationError(), "Give the sequence a title.")
        routine.title = "Yoga"
        routine.rounds = 0
        XCTAssertEqual(routine.validationError(), "Rounds must be at least 1.")
        routine.rounds = 1
        routine.template = .custom([])
        XCTAssertEqual(routine.validationError(), "Add at least one interval.")
        routine.template = .custom([Interval(label: "Pose", seconds: 0.5)])
        XCTAssertEqual(routine.validationError(), "Every interval must last at least 1 second.")
        routine.template = .custom([Interval(label: "", seconds: 5)])
        XCTAssertEqual(routine.validationError(), "Every interval needs a label.")
        routine.template = .emom(EmomConfig(exercises: [Exercise(name: "Squats", reps: 0)]))
        XCTAssertEqual(routine.validationError(), "Reps must be blank or at least 1.")
    }

    func testJSONRoundTripOfEveryTemplate() throws {
        let routines = TemplateKind.allCases.map {
            Routine(title: $0.title, notes: "n", template: .starter($0), rounds: 2, prepSeconds: 5)
        } + [Routine(title: "478", template: .breathing(.relax478), rounds: 4)]
        let data = try JSONEncoder().encode(routines)
        let decoded = try JSONDecoder().decode([Routine].self, from: data)
        XCTAssertEqual(decoded, routines)
    }
}

final class TemplateEditingTests: XCTestCase {
    func testConfigPropertiesReadAndWrite() {
        var template = Template.starter(.tabata)
        template.tabataConfig.workSeconds = 40
        XCTAssertEqual(template.tabataConfig.workSeconds, 40)
        XCTAssertEqual(template.kind, .tabata)

        template = .starter(.breathing)
        template.breathingConfig.holdOut = 0
        XCTAssertEqual(template.intervals(round: 0).count, 3)

        template = .starter(.custom)
        template.customIntervals.append(Interval(label: "Rest", seconds: 10, role: .rest))
        XCTAssertEqual(template.customIntervals.count, 3)
    }
}
