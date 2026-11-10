// SequenceTemplate expansion (spec 4). Builds the intervals of one round from a
// template's own settings. `round` starts at 0.

export const BREATHING_ROLES = ["inhale", "hold", "exhale"]

export function isBreathing(role) {
  return BREATHING_ROLES.includes(role)
}

// "10 × Deadlifts", or just the label when there are no reps.
export function displayLabel(interval) {
  return interval.reps == null ? interval.label : `${interval.reps} × ${interval.label}`
}

const num = (value) => Number(value) || 0
const reps = (value) => (value == null || value === "" ? null : Number(value))

export function intervals(kind, settings, round = 0) {
  switch (kind) {
    case "emom":
      return (settings.exercises || []).map((exercise) => ({
        label: String(exercise.name ?? ""),
        seconds: num(settings.stepSeconds),
        reps: reps(exercise.reps),
        role: String(exercise.name ?? "").toLowerCase() === "rest" ? "rest" : "work",
      }))
    case "tabata": {
      const names = (settings.exercises || []).map((name) => String(name).trim()).filter(Boolean)
      const label = names.length === 0 ? "Work" : names[round % names.length]
      const result = [{ label, seconds: num(settings.workSeconds), reps: null, role: "work" }]
      if (num(settings.restSeconds) > 0) {
        result.push({ label: "Rest", seconds: num(settings.restSeconds), reps: null, role: "rest" })
      }
      return result
    }
    case "breathing":
      return [
        ["Inhale", settings.inhale, "inhale"],
        ["Hold", settings.holdIn, "hold"],
        ["Exhale", settings.exhale, "exhale"],
        ["Hold", settings.holdOut, "hold"],
      ]
        .filter(([, seconds]) => num(seconds) > 0)
        .map(([label, seconds, role]) => ({ label, seconds: num(seconds), reps: null, role }))
    case "custom":
      return (settings.intervals || []).map((interval) => ({
        label: String(interval.label ?? ""),
        seconds: num(interval.seconds),
        reps: reps(interval.reps),
        role: interval.role || "work",
      }))
    default:
      return []
  }
}
