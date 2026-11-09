import NoGymKit
import Observation
import SwiftUI
import UIKit

/// One live run of a sequence. It owns the clock and the sounds.
/// The screen reads `position(at:)` to draw itself; the clock does the timing.
@MainActor
@Observable
final class RunSession {
    let routine: Routine
    let timeline: Timeline
    private(set) var clock: RunClock
    private(set) var isFinished = false

    private let cues: [Cue]
    private let player = CuePlayer()
    private var lastStepIndex = Int.min
    private var loop: Task<Void, Never>?

    init(routine: Routine) {
        self.routine = routine
        timeline = routine.timeline
        cues = CueSchedule.cues(for: routine.timeline, sound: routine.sound)
        clock = RunClock(startedAt: .now)
    }

    var isPaused: Bool { clock.isPaused }

    func position(at date: Date) -> RunPosition {
        clock.position(in: timeline, at: date)
    }

    // MARK: - Controls

    func start() {
        clock = RunClock(startedAt: .now)
        // Keep the screen on while training.
        UIApplication.shared.isIdleTimerDisabled = true
        player.volume = routine.sound.volume
        player.onRestart = { [weak self] in self?.scheduleSounds() }
        scheduleSounds()
        // A light loop for things the screen can't do: haptics and noticing the end.
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func togglePause() {
        if clock.isPaused {
            clock.resume(at: .now)
            scheduleSounds()
        } else {
            clock.pause(at: .now)
            player.stopAll()
        }
    }

    func skipForward() {
        clock.skipForward(in: timeline, at: .now)
        afterSkip()
    }

    func skipBackward() {
        clock.skipBackward(in: timeline, at: .now)
        afterSkip()
    }

    func stop() {
        loop?.cancel()
        loop = nil
        player.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Internals

    private func afterSkip() {
        // Don't buzz for a step you jumped to on purpose.
        lastStepIndex = position(at: .now).stepIndex
        if clock.isPaused { player.stopAll() } else { scheduleSounds() }
        tick()
    }

    private func scheduleSounds() {
        guard !clock.isPaused, !isFinished else { return }
        player.schedule(cues, elapsed: clock.elapsed(at: .now))
    }

    private func tick() {
        let position = position(at: .now)
        if position.stepIndex != lastStepIndex {
            if lastStepIndex != Int.min, routine.sound.haptics {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            lastStepIndex = position.stepIndex
        }
        if position.phase == .done, !isFinished {
            isFinished = true
            loop?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
            // Let the finish sound ring out before the audio turns off.
            Task { [player] in
                try? await Task.sleep(for: .seconds(3))
                player.deactivate()
            }
        }
    }
}

extension Role {
    var color: Color {
        switch self {
        case .work: .green
        case .rest: .blue
        case .inhale: .teal
        case .hold: .indigo
        case .exhale: .purple
        }
    }
}
