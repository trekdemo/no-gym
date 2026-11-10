import { test } from "node:test"
import assert from "node:assert/strict"
import { samples, countdownTick, breath, SOUND_CHOICES } from "nogym/synth"

const peak = (data) => data.reduce((max, v) => Math.max(max, Math.abs(v)), 0)

// Spec 13.8.
test("every sound except none is audible, in range and starts and ends silent", () => {
  for (const choice of SOUND_CHOICES.filter((c) => c !== "none")) {
    const data = samples(choice)
    assert.ok(data.length > 0, choice)
    assert.ok(peak(data) > 0.1, `${choice} peak`)
    assert.ok(peak(data) <= 1, `${choice} peak`)
    assert.ok(Math.abs(data[0]) < 0.01, `${choice} first sample`)
    assert.ok(Math.abs(data[data.length - 1]) < 0.01, `${choice} last sample`)
  }
})

test("none has no samples", () => {
  assert.equal(samples("none").length, 0)
})

test("breathing tones last the whole phase", () => {
  assert.equal(breath("inhale", 4, 8000).length, 32000)
  assert.equal(breath("exhale", 5.5, 8000).length, 44000)
})

test("the hold tone is at most 0.8 s", () => {
  assert.ok(breath("hold", 7, 8000).length <= 6400)
})

test("work and rest have no breathing tone", () => {
  assert.equal(breath("work", 4, 8000).length, 0)
  assert.equal(breath("rest", 4, 8000).length, 0)
})

test("the countdown tick is 0.15 s", () => {
  assert.equal(countdownTick(1000).length, 150)
})

test("mixes are capped at a peak of 0.9", () => {
  assert.ok(peak(samples("double_beep")) <= 0.9 + 1e-6)
  assert.ok(peak(samples("chime")) <= 0.9 + 1e-6)
})
