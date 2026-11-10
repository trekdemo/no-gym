import { test } from "node:test"
import assert from "node:assert/strict"
import { clock, duration, plural, summary, parseExercises, formatExercises } from "nogym/format"
import { tabataTimeline } from "./helpers.js"

// Spec 13.6.
test("clock rounds up", () => {
  assert.deepEqual([0, 4.2, 240, 3723].map(clock), ["0:00", "0:05", "4:00", "1:02:03"])
})

test("duration", () => {
  assert.deepEqual([20, 5.5, 60, 90].map(duration), ["20 s", "5.5 s", "1 min", "1 min 30 s"])
})

test("summary and plural", () => {
  assert.equal(summary(8, tabataTimeline({ rounds: 8 }).workDuration), "8 rounds · 4:00")
  assert.deepEqual([plural(1, "round"), plural(2, "round")], ["1 round", "2 rounds"])
})

// Spec 13.7: the EMOM paste format.
test("paste format, parsing", () => {
  const parsed = parseExercises("Min 1: 10 Deadlifts\nmin 2 - 12x Sit-Ups\n\n  Minute 3: REST\n5 × Burpees\n")
  assert.deepEqual(parsed, [
    { name: "Deadlifts", reps: 10 },
    { name: "Sit-Ups", reps: 12 },
    { name: "REST", reps: null },
    { name: "Burpees", reps: 5 },
  ])
})

test("paste format, writing and reading back", () => {
  const exercises = [{ name: "Deadlifts", reps: 10 }, { name: "REST", reps: null }]
  const text = formatExercises(exercises)
  assert.equal(text, "10 Deadlifts\nREST\n")
  assert.deepEqual(parseExercises(text), exercises)
})
