import Foundation

/// Where a run is at a given moment.
public struct RunPosition: Hashable, Sendable {
    public enum Phase: Hashable, Sendable { case prep, active, done }

    public var phase: Phase
    /// Index into `Timeline.steps`. -1 during prep, `steps.count` when done.
    public var stepIndex: Int
    /// Seconds since the run started, prep included and pauses left out.
    public var elapsed: TimeInterval
    /// Seconds left in the current period (prep or step).
    public var remaining: TimeInterval
    /// Length of the current period.
    public var length: TimeInterval

    /// How much of the current period has passed, from 0 to 1.
    public var fraction: Double {
        length > 0 ? min(1, max(0, 1 - remaining / length)) : 1
    }

    /// The whole seconds shown on the countdown. 4.2 s left shows as 5, like a kitchen timer.
    public var displaySeconds: Int { Int(remaining.rounded(.up)) }
}

/// The run's clock. It works out the position from timestamps, not from a counter,
/// so a late or skipped timer tick can't make the clock drift.
/// This is the same idea as `runPosition()` in the HTML prototype.
public struct RunClock: Hashable, Sendable {
    public private(set) var startedAt: Date
    public private(set) var pausedAt: Date?
    public private(set) var pausedTotal: TimeInterval = 0
    /// Moves the clock when you skip forwards or backwards.
    public private(set) var skipOffset: TimeInterval = 0

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }

    public var isPaused: Bool { pausedAt != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        (pausedAt ?? now).timeIntervalSince(startedAt) - pausedTotal + skipOffset
    }

    public mutating func pause(at now: Date) {
        guard pausedAt == nil else { return }
        pausedAt = now
    }

    public mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        pausedTotal += now.timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }

    /// Moves the clock so that `elapsed(at: now)` becomes `target`.
    public mutating func jump(to target: TimeInterval, at now: Date) {
        skipOffset += target - elapsed(at: now)
    }

    public func position(in timeline: Timeline, at now: Date) -> RunPosition {
        let elapsed = max(0, elapsed(at: now))
        if elapsed < timeline.prepDuration {
            return RunPosition(phase: .prep, stepIndex: -1, elapsed: elapsed,
                               remaining: timeline.prepDuration - elapsed, length: timeline.prepDuration)
        }
        guard let index = timeline.stepIndex(at: elapsed) else {
            return RunPosition(phase: .done, stepIndex: timeline.steps.count, elapsed: elapsed, remaining: 0, length: 0)
        }
        let step = timeline.steps[index]
        return RunPosition(phase: .active, stepIndex: index, elapsed: elapsed,
                           remaining: step.end - elapsed, length: step.duration)
    }

    /// Jumps to the start of the next step, or to the end on the last one.
    public mutating func skipForward(in timeline: Timeline, at now: Date) {
        let position = position(in: timeline, at: now)
        let next = position.stepIndex + 1
        let target = next < timeline.steps.count ? timeline.steps[next].start : timeline.duration
        jump(to: target, at: now)
    }

    /// Like a music player: goes back to the start of the current step,
    /// or to the step before if the current one started less than 2 seconds ago.
    public mutating func skipBackward(in timeline: Timeline, at now: Date) {
        let position = position(in: timeline, at: now)
        guard position.phase != .prep else {
            jump(to: 0, at: now)
            return
        }
        let index = min(position.stepIndex, timeline.steps.count - 1)
        guard index >= 0 else { return }
        let current = timeline.steps[index]
        if position.elapsed - current.start >= 2 || position.phase == .done {
            jump(to: current.start, at: now)
        } else if index > 0 {
            jump(to: timeline.steps[index - 1].start, at: now)
        } else {
            jump(to: 0, at: now)
        }
    }
}
