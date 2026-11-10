import { test } from "node:test"
import assert from "node:assert/strict"
import { breathScale } from "nogym/breath"
import { Timeline } from "nogym/timeline"
import { BOX } from "./helpers.js"

// Spec 13.5: Box, 1 round, prep 0. The steps are inhale, hold, exhale, hold.
const box = new Timeline({ kind: "breathing", settings: BOX, rounds: 1, prepSeconds: 0 })

test("breathing circle scale", () => {
  const cases = [
    [0, 0, 0.45],
    [0, 1, 1],
    [1, 0.5, 1],
    [2, 1, 0.45],
    [3, 0.5, 0.45],
    [-1, 0.5, 0.45],
  ]
  for (const [step, fraction, scale] of cases) {
    assert.ok(Math.abs(breathScale(box, step, fraction) - scale) < 1e-9, `step ${step}, fraction ${fraction}`)
  }
})

test("a hold with no breath before it is small", () => {
  const holdFirst = new Timeline({
    kind: "custom", settings: { intervals: [{ label: "Hold", seconds: 4, role: "hold" }] }, rounds: 1, prepSeconds: 0,
  })
  assert.equal(breathScale(holdFirst, 0, 0.5), 0.45)
})

test("inhale halfway is halfway between small and 1", () => {
  assert.ok(Math.abs(breathScale(box, 0, 0.5) - 0.725) < 1e-9)
})
