import { Timeline } from "nogym/timeline"

// Spec 13.3: prep 10 and Tabata 20/10 over 2 rounds.
export function tabataTimeline({ rounds = 2, prepSeconds = 10, workSeconds = 20, restSeconds = 10, exercises = [] } = {}) {
  return new Timeline({ kind: "tabata", settings: { workSeconds, restSeconds, exercises }, rounds, prepSeconds })
}

// Default EMOM/Tabata sounds (spec 3.4).
export const DEFAULT_SOUND = {
  countdown: "last3", intervalEnd: "beep", roundEnd: "double_beep", finish: "bell",
  breathingGuide: false, haptics: true, volume: 0.8,
}

export const BREATHING_SOUND = {
  countdown: "off", intervalEnd: "none", roundEnd: "none", finish: "bell",
  breathingGuide: true, haptics: false, volume: 0.6,
}

export const BOX = { inhale: 4, holdIn: 4, exhale: 4, holdOut: 4 }
