import Foundation

/// One interval in one round, placed on the run's time line.
public struct Step: Hashable, Sendable {
    /// Round number, starting at 1.
    public var round: Int
    /// Position inside the round, starting at 0.
    public var indexInRound: Int
    public var interval: Interval
    /// Seconds from the start of the run, prep included.
    public var start: TimeInterval
    public var end: TimeInterval

    public var duration: TimeInterval { end - start }
}

/// A routine laid out in time: prep first, then every interval of every round.
public struct Timeline: Hashable, Sendable {
    public let prepDuration: TimeInterval
    public let steps: [Step]
    public let rounds: Int
    public let stepsPerRound: Int

    public init(routine: Routine) {
        self.init(template: routine.template, rounds: routine.rounds, prepSeconds: routine.prepSeconds)
    }

    public init(template: Template, rounds: Int, prepSeconds: Double) {
        prepDuration = max(0, prepSeconds)
        self.rounds = max(0, rounds)
        var steps: [Step] = []
        var time = prepDuration
        var perRound = 0
        for round in 0..<self.rounds {
            let intervals = template.intervals(round: round)
            perRound = max(perRound, intervals.count)
            for (index, interval) in intervals.enumerated() {
                let length = max(0, interval.seconds)
                steps.append(Step(round: round + 1, indexInRound: index, interval: interval,
                                  start: time, end: time + length))
                time += length
            }
        }
        self.steps = steps
        stepsPerRound = perRound
    }

    /// Prep plus all intervals.
    public var duration: TimeInterval { steps.last?.end ?? prepDuration }

    /// All intervals, without the prep.
    public var workDuration: TimeInterval { duration - prepDuration }

    public func isLastInRound(_ index: Int) -> Bool {
        index == steps.count - 1 || steps[index + 1].round != steps[index].round
    }

    /// The step running at `elapsed` seconds into the run, found by binary search.
    /// Returns nil during prep and after the end.
    public func stepIndex(at elapsed: TimeInterval) -> Int? {
        guard elapsed >= prepDuration, elapsed < duration, !steps.isEmpty else { return nil }
        var low = 0
        var high = steps.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if steps[mid].start <= elapsed { low = mid } else { high = mid - 1 }
        }
        return low
    }
}
