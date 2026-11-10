// The run clock (spec 7). The position is always worked out from timestamps,
// never by counting ticks, so a late or skipped redraw can't make it drift.
// Times are in seconds; the caller supplies `now` (performance.now() / 1000 in the browser).

export class RunClock {
  constructor(startedAt) {
    this.startedAt = startedAt
    this.pausedAt = null
    this.pausedTotal = 0
    this.skipOffset = 0
  }

  get isPaused() {
    return this.pausedAt !== null
  }

  elapsed(now) {
    return (this.pausedAt ?? now) - this.startedAt - this.pausedTotal + this.skipOffset
  }

  // A second pause keeps the first pause time.
  pause(now) {
    if (this.pausedAt === null) this.pausedAt = now
  }

  resume(now) {
    if (this.pausedAt === null) return
    this.pausedTotal += now - this.pausedAt
    this.pausedAt = null
  }

  // Moves the clock so that elapsed(now) becomes `target`. Works while paused, too.
  jump(target, now) {
    this.skipOffset += target - this.elapsed(now)
  }

  position(timeline, now) {
    const elapsed = Math.max(0, this.elapsed(now))
    let phase, stepIndex, remaining, length
    if (elapsed < timeline.prepDuration) {
      ;[phase, stepIndex, remaining, length] = ["prep", -1, timeline.prepDuration - elapsed, timeline.prepDuration]
    } else {
      const index = timeline.stepIndexAt(elapsed)
      if (index < 0) {
        ;[phase, stepIndex, remaining, length] = ["done", timeline.steps.length, 0, 0]
      } else {
        const step = timeline.steps[index]
        ;[phase, stepIndex, remaining, length] = ["active", index, step.end - elapsed, step.end - step.start]
      }
    }
    const fraction = length > 0 ? Math.min(1, Math.max(0, 1 - remaining / length)) : 1
    return { phase, stepIndex, elapsed, remaining, length, fraction, displaySeconds: Math.ceil(remaining) }
  }

  // To the start of the next step; on the last step, to the end of the run.
  skipForward(timeline, now) {
    const next = this.position(timeline, now).stepIndex + 1
    this.jump(next < timeline.steps.length ? timeline.steps[next].start : timeline.duration, now)
  }

  // Like a music player: back to the start of the current step, or to the step
  // before if the current one started less than 2 seconds ago.
  skipBackward(timeline, now) {
    const position = this.position(timeline, now)
    if (position.phase === "prep") return this.jump(0, now)
    const index = Math.min(position.stepIndex, timeline.steps.length - 1)
    if (index < 0) return
    const current = timeline.steps[index]
    if (position.elapsed - current.start >= 2 || position.phase === "done") {
      this.jump(current.start, now)
    } else if (index > 0) {
      this.jump(timeline.steps[index - 1].start, now)
    } else {
      this.jump(0, now)
    }
  }
}
