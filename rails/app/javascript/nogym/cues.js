// The cue schedule (spec 8): every sound of a run, worked out up front.
import { isBreathing } from "nogym/template"

const COUNTDOWN_SECONDS = { off: 0, last3: 3, last5: 5 }

// The most important sound that is not "none" wins (spec 8.3).
export function boundarySound(boundary, sound) {
  const order = {
    go: [sound.intervalEnd],
    interval: [sound.intervalEnd],
    round: [sound.roundEnd, sound.intervalEnd],
    finish: [sound.finish, sound.roundEnd, sound.intervalEnd],
  }[boundary]
  return order.find((choice) => choice && choice !== "none") ?? null
}

// Cues look like
//   { at, type: "tick" }
//   { at, type: "boundary", boundary: "go" | "interval" | "round" | "finish", sound }
//   { at, type: "breathe", role, duration }
export function cueSchedule(timeline, sound) {
  const cues = []
  const periods = []
  const { steps } = timeline
  if (timeline.prepDuration > 0 && steps.length) periods.push({ start: 0, end: timeline.prepDuration, boundary: "go" })
  steps.forEach((step, index) => {
    const boundary = index === steps.length - 1 ? "finish" : timeline.isLastInRound(index) ? "round" : "interval"
    periods.push({ start: step.start, end: step.end, boundary })
  })

  const ticks = COUNTDOWN_SECONDS[sound.countdown] ?? 0
  for (const period of periods) {
    for (let k = ticks; k >= 1; k--) {
      const at = period.end - k
      // A period never ticks at or before its own start.
      if (at > period.start + 0.001) cues.push({ at, type: "tick" })
    }
    const choice = boundarySound(period.boundary, sound)
    if (choice) cues.push({ at: period.end, type: "boundary", boundary: period.boundary, sound: choice })
  }

  if (sound.breathingGuide) {
    for (const step of steps) {
      const duration = step.end - step.start
      if (isBreathing(step.interval.role) && duration > 0) {
        cues.push({ at: step.start, type: "breathe", role: step.interval.role, duration })
      }
    }
  }

  // Stable sort keeps a tick before the boundary sound that shares its moment.
  return cues.sort((a, b) => a.at - b.at)
}

// On start, resume or skip (spec 8.5): every cue whose time is at or after
// elapsed − 0.05 s plays at now + (cue time − elapsed) on the audio clock.
// Anything earlier, such as a breathing tone that has already started, is left out.
export const LATE_TOLERANCE = 0.05

export function planCues(cues, elapsed, now) {
  return cues
    .filter((cue) => cue.at >= elapsed - LATE_TOLERANCE)
    .map((cue) => ({ cue, when: now + (cue.at - elapsed) }))
}
