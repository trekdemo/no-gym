import { test } from "node:test"
import assert from "node:assert/strict"
import { intervals, displayLabel } from "nogym/template"
import { Timeline } from "nogym/timeline"
import { tabataTimeline } from "./helpers.js"

// Spec 13.1, as the run screen sees it.
test("Tabata 20/10, 8 rounds, prep 10", () => {
  const timeline = tabataTimeline({ rounds: 8 })
  assert.equal(timeline.steps.length, 16)
  assert.equal(timeline.workDuration, 240)
  assert.equal(timeline.duration, 250)
  assert.deepEqual(timeline.steps.slice(0, 2).map((s) => s.interval.role), ["work", "rest"])
})

test("Tabata names cycle and blank names are dropped", () => {
  const timeline = tabataTimeline({ rounds: 4, prepSeconds: 0, exercises: ["Squats", " ", "Push-ups"] })
  const labels = timeline.steps.filter((s) => s.interval.role === "work").map((s) => s.interval.label)
  assert.deepEqual(labels, ["Squats", "Push-ups", "Squats", "Push-ups"])
})

test("Tabata with no rest is only work", () => {
  assert.deepEqual(intervals("tabata", { workSeconds: 30, restSeconds: 0, exercises: [] }, 0).map((i) => i.label), ["Work"])
})

test("Breathing leaves out zero phases", () => {
  assert.deepEqual(intervals("breathing", { inhale: 4, holdIn: 7, exhale: 8, holdOut: 0 }).map((i) => i.label), ["Inhale", "Hold", "Exhale"])
  assert.deepEqual(intervals("breathing", { inhale: 5.5, holdIn: 0, exhale: 5.5, holdOut: 0 }).map((i) => i.role), ["inhale", "exhale"])
  assert.equal(intervals("breathing", { inhale: 4, holdIn: 4, exhale: 4, holdOut: 4 }).length, 4)
})

test("EMOM uses the step length and marks rest", () => {
  const list = intervals("emom", { stepSeconds: 60, exercises: [{ name: "Deadlifts", reps: 10 }, { name: "REST", reps: null }] })
  assert.deepEqual(list.map((i) => i.seconds), [60, 60])
  assert.deepEqual(list.map((i) => i.role), ["work", "rest"])
  assert.deepEqual(list.map(displayLabel), ["10 × Deadlifts", "REST"])
})

test("timeline steps, rounds and last in round (13.3)", () => {
  const timeline = tabataTimeline()
  assert.deepEqual(timeline.steps.map((s) => s.start), [10, 30, 40, 60])
  assert.equal(timeline.duration, 70)
  assert.deepEqual(timeline.steps.map((s) => s.round), [1, 1, 2, 2])
  assert.equal(timeline.isLastInRound(1), true)
  assert.equal(timeline.isLastInRound(2), false)
  assert.equal(timeline.stepsPerRound, 2)
})

test("an empty sequence lasts as long as its prep", () => {
  const timeline = new Timeline({ kind: "custom", settings: { intervals: [] }, rounds: 2, prepSeconds: 10 })
  assert.equal(timeline.duration, 10)
  assert.equal(timeline.workDuration, 0)
})
