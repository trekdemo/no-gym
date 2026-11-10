// Text formats (spec 13.6) and the EMOM paste format (spec 10.3, 13.7).

// "0:05", "4:00", "1:02:03". Rounds up, like the countdown.
export function clock(seconds) {
  const total = Math.max(0, Math.ceil(seconds))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const secs = total % 60
  const pad = (n) => String(n).padStart(2, "0")
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(secs)}` : `${minutes}:${pad(secs)}`
}

// "20 s", "5.5 s", "1 min", "1 min 30 s".
export function duration(seconds) {
  if (seconds < 60) {
    return Math.round(seconds) === seconds ? `${seconds} s` : `${seconds.toFixed(1)} s`
  }
  const whole = Math.round(seconds)
  const minutes = Math.floor(whole / 60)
  const rest = whole % 60
  return rest === 0 ? `${minutes} min` : `${minutes} min ${rest} s`
}

export function plural(count, noun) {
  return `${count} ${noun}${count === 1 ? "" : "s"}`
}

// "8 rounds · 4:00"
export function summary(rounds, workDuration) {
  return `${plural(rounds, "round")} · ${clock(workDuration)}`
}

const PREFIX = /^min(ute)?\s*\d+\s*[:.\-–]\s*/i
const COUNTED = /^(\d+)\s*[x×]?\s+(.+)$/i

// One exercise per non-blank line, like "Min 1: 10 Deadlifts" or "5 × Burpees".
export function parseExercises(text) {
  return text.split(/\r?\n|\r/).flatMap((raw) => {
    const line = raw.trim().replace(PREFIX, "")
    if (!line) return []
    const counted = line.match(COUNTED)
    if (counted) {
      const name = counted[2].trim()
      if (name) return [{ name, reps: parseInt(counted[1], 10) }]
    }
    return [{ name: line, reps: null }]
  })
}

// The reverse of parseExercises: "<reps> <name>" per line, or just the name.
export function formatExercises(exercises) {
  return exercises.map(({ name, reps }) => (reps == null ? name : `${reps} ${name}`) + "\n").join("")
}
