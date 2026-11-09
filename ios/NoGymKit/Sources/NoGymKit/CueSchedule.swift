import Foundation

/// Why a boundary sound plays.
public enum Boundary: Hashable, Sendable {
    /// Prep is over and the first interval starts.
    case go
    case interval
    case round
    case finish
}

public enum CueKind: Hashable, Sendable {
    /// A short tick in the last seconds of a period.
    case countdown
    /// A sound at the end of a period.
    case boundary(Boundary, SoundChoice)
    /// A breathing guide tone that lasts the whole phase.
    case breathe(Role, duration: TimeInterval)
}

/// A sound to play at a moment of the run.
public struct Cue: Hashable, Sendable {
    /// Seconds from the start of the run, prep included.
    public var at: TimeInterval
    public var kind: CueKind
}

/// Builds every sound of a run up front. The audio player schedules them on the
/// audio clock, so they play on time even when the phone is locked.
public enum CueSchedule {
    public static func cues(for timeline: Timeline, sound: SoundSettings) -> [Cue] {
        var cues: [Cue] = []

        // Each period is the prep or one step. It ends with ticks and a boundary sound.
        var periods: [(start: TimeInterval, end: TimeInterval, boundary: Boundary)] = []
        if timeline.prepDuration > 0, !timeline.steps.isEmpty {
            periods.append((0, timeline.prepDuration, .go))
        }
        for (index, step) in timeline.steps.enumerated() {
            let boundary: Boundary = index == timeline.steps.count - 1 ? .finish
                : timeline.isLastInRound(index) ? .round : .interval
            periods.append((step.start, step.end, boundary))
        }

        for period in periods {
            let ticks = sound.countdown.seconds
            if ticks > 0 {
                for second in stride(from: ticks, through: 1, by: -1) {
                    let at = period.end - Double(second)
                    // No tick at or before the period's own start.
                    if at > period.start + 0.001 { cues.append(Cue(at: at, kind: .countdown)) }
                }
            }
            if let choice = choice(for: period.boundary, in: sound) {
                cues.append(Cue(at: period.end, kind: .boundary(period.boundary, choice)))
            }
        }

        if sound.breathingGuide {
            for step in timeline.steps where step.interval.role.isBreathing && step.duration > 0 {
                cues.append(Cue(at: step.start, kind: .breathe(step.interval.role, duration: step.duration)))
            }
        }

        return cues.sorted { $0.at < $1.at }
    }

    /// The most important sound that is turned on wins: finish, then round end, then interval end.
    static func choice(for boundary: Boundary, in sound: SoundSettings) -> SoundChoice? {
        let order: [SoundChoice] = switch boundary {
        case .go, .interval: [sound.intervalEnd]
        case .round: [sound.roundEnd, sound.intervalEnd]
        case .finish: [sound.finish, sound.roundEnd, sound.intervalEnd]
        }
        return order.first { $0 != .off }
    }
}
