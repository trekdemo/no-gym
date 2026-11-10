import { test } from "node:test"
import assert from "node:assert/strict"
import { RunClock } from "nogym/clock"
import { tabataTimeline } from "./helpers.js"

// Spec 13.3. The clock starts at wall-clock 0, so elapsed equals the time
// unless it is paused or skipped.
const timeline = tabataTimeline()

const positionAt = (elapsed) => new RunClock(0).position(timeline, elapsed)

test("position by elapsed time", () => {
  const cases = [
    [0, "prep", -1],
    [4.2, "prep", -1],
    [15, "active", 0],
    [30, "active", 1], // a boundary belongs to the next step
    [69.9, "active", 3],
    [70, "done", 4],
  ]
  for (const [elapsed, phase, stepIndex] of cases) {
    const position = positionAt(elapsed)
    assert.equal(position.phase, phase, `phase at ${elapsed}`)
    assert.equal(position.stepIndex, stepIndex, `step at ${elapsed}`)
  }
  assert.equal(positionAt(4.2).displaySeconds, 6)
  assert.equal(positionAt(15).remaining, 15)
  assert.equal(positionAt(15).fraction, 0.25)
  assert.equal(positionAt(70).remaining, 0)
  assert.equal(positionAt(70).fraction, 1)
})

test("elapsed before the start counts as 0", () => {
  const clock = new RunClock(10)
  assert.equal(clock.position(timeline, 5).elapsed, 0)
})

test("pause and resume", () => {
  const clock = new RunClock(0)
  clock.pause(12)
  assert.equal(clock.elapsed(500), 12)
  assert.equal(clock.isPaused, true)

  clock.resume(100)
  assert.equal(clock.elapsed(103), 15)

  clock.pause(110)
  clock.pause(120) // ignored: keeps the first pause time
  clock.resume(130)
  assert.equal(clock.elapsed(130), 22)
  assert.equal(clock.isPaused, false)
})

test("resume while running changes nothing", () => {
  const clock = new RunClock(0)
  clock.resume(5)
  assert.equal(clock.elapsed(8), 8)
})

test("Next during prep goes to the first step, then to the next one", () => {
  const clock = new RunClock(0)
  clock.skipForward(timeline, 3)
  assert.equal(clock.elapsed(3), 10)
  clock.skipForward(timeline, 3)
  assert.equal(clock.elapsed(3), 30)
  assert.equal(clock.position(timeline, 3).stepIndex, 1)
})

test("Previous 1 s into a step goes to the step before", () => {
  const clock = new RunClock(0)
  clock.skipForward(timeline, 3)
  clock.skipForward(timeline, 3) // step 1 at 30
  clock.skipBackward(timeline, 4) // 1 s into step 1
  assert.equal(clock.elapsed(4), 10)
})

test("Previous 5 s into step 0 restarts it", () => {
  const clock = new RunClock(0)
  clock.jump(15, 9)
  clock.skipBackward(timeline, 9)
  assert.equal(clock.elapsed(9), 10)
})

test("Previous at step 0's start goes back to the prep", () => {
  const clock = new RunClock(0)
  clock.jump(10, 9)
  clock.skipBackward(timeline, 9)
  assert.equal(clock.position(timeline, 9).phase, "prep")
  assert.equal(clock.elapsed(9), 0)
})

test("Previous during prep jumps to 0", () => {
  const clock = new RunClock(0)
  clock.skipBackward(timeline, 6)
  assert.equal(clock.elapsed(6), 0)
})

test("Next on the last step ends the run", () => {
  const clock = new RunClock(0)
  clock.jump(65, 1)
  clock.skipForward(timeline, 1)
  assert.equal(clock.position(timeline, 1).phase, "done")
})

test("Previous when done restarts the last step", () => {
  const clock = new RunClock(0)
  clock.jump(80, 1)
  clock.skipBackward(timeline, 1)
  assert.equal(clock.elapsed(1), 60)
})

test("a skip while paused stays paused", () => {
  const clock = new RunClock(0)
  clock.pause(15)
  clock.skipForward(timeline, 20)
  assert.equal(clock.elapsed(50), 30)
  assert.equal(clock.isPaused, true)
})
