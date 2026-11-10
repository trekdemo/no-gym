import { test } from "node:test"
import assert from "node:assert/strict"
import { cueSchedule, boundarySound, planCues } from "nogym/cues"
import { Timeline } from "nogym/timeline"
import { tabataTimeline, DEFAULT_SOUND, BREATHING_SOUND, BOX } from "./helpers.js"

// Spec 13.4: same timeline as 13.3, default EMOM/Tabata sounds.
const timeline = tabataTimeline()
const boundaries = (cues) => cues.filter((cue) => cue.type === "boundary")
const ticks = (cues) => cues.filter((cue) => cue.type === "tick").map((cue) => cue.at)

test("default sounds at every boundary", () => {
  const cues = boundaries(cueSchedule(timeline, DEFAULT_SOUND))
  assert.deepEqual(cues.map((c) => c.at), [10, 30, 40, 60, 70])
  assert.deepEqual(cues.map((c) => c.boundary), ["go", "interval", "round", "interval", "finish"])
  assert.deepEqual(cues.map((c) => c.sound), ["beep", "beep", "double_beep", "beep", "bell"])
})

test("with roundEnd and finish off, every boundary falls back to the interval sound", () => {
  const cues = boundaries(cueSchedule(timeline, { ...DEFAULT_SOUND, roundEnd: "none", finish: "none" }))
  assert.deepEqual(cues.map((c) => c.sound), ["beep", "beep", "beep", "beep", "beep"])
})

test("every sound none and countdown off gives no cues at all", () => {
  const sound = { ...DEFAULT_SOUND, countdown: "off", intervalEnd: "none", roundEnd: "none", finish: "none" }
  assert.deepEqual(cueSchedule(timeline, sound), [])
})

test("countdown last 3 ticks in the last 3 seconds of every period", () => {
  assert.deepEqual(ticks(cueSchedule(timeline, DEFAULT_SOUND)), [7, 8, 9, 27, 28, 29, 37, 38, 39, 57, 58, 59, 67, 68, 69])
})

test("a period never ticks at or before its own start", () => {
  const short = new Timeline({ kind: "custom", settings: { intervals: [{ label: "Go", seconds: 2, role: "work" }] }, rounds: 1, prepSeconds: 0 })
  assert.deepEqual(ticks(cueSchedule(short, { ...DEFAULT_SOUND, countdown: "last5" })), [1])
})

test("cues are sorted by time", () => {
  const settings = [DEFAULT_SOUND, { ...DEFAULT_SOUND, countdown: "last5", breathingGuide: true }, BREATHING_SOUND]
  const timelines = [timeline, new Timeline({ kind: "breathing", settings: BOX, rounds: 3, prepSeconds: 3 })]
  for (const sound of settings) {
    for (const t of timelines) {
      const times = cueSchedule(t, sound).map((cue) => cue.at)
      assert.deepEqual(times, [...times].sort((a, b) => a - b))
    }
  }
})

test("Box breathing, 2 rounds, prep 5, breathing defaults", () => {
  const box = new Timeline({ kind: "breathing", settings: BOX, rounds: 2, prepSeconds: 5 })
  const cues = cueSchedule(box, BREATHING_SOUND)
  const breaths = cues.filter((cue) => cue.type === "breathe")
  assert.deepEqual(breaths.map((c) => c.at), [5, 9, 13, 17, 21, 25, 29, 33])
  assert.ok(breaths.every((c) => c.duration === 4))
  assert.deepEqual(breaths.map((c) => c.role), ["inhale", "hold", "exhale", "hold", "inhale", "hold", "exhale", "hold"])
  assert.deepEqual(ticks(cues), [])
  assert.deepEqual(boundaries(cues).map((c) => [c.at, c.boundary, c.sound]), [[37, "finish", "bell"]])
})

test("boundary sound priority", () => {
  const sound = { intervalEnd: "beep", roundEnd: "none", finish: "none" }
  assert.equal(boundarySound("go", sound), "beep")
  assert.equal(boundarySound("finish", { ...sound, roundEnd: "chime" }), "chime")
  assert.equal(boundarySound("round", { intervalEnd: "none", roundEnd: "none", finish: "bell" }), null)
})

// Spec 8.5: scheduling on start, resume and skip.
test("on start every cue plays at now + its time", () => {
  const cues = cueSchedule(timeline, DEFAULT_SOUND)
  const planned = planCues(cues, 0, 100)
  assert.equal(planned.length, cues.length)
  assert.deepEqual(planned.slice(0, 4).map((p) => p.when), [107, 108, 109, 110])
})

test("on resume only the cues still to come are scheduled, relative to the audio clock", () => {
  const cues = cueSchedule(timeline, DEFAULT_SOUND)
  const planned = planCues(cues, 35, 1000)
  assert.deepEqual(planned.map((p) => p.cue.at), [37, 38, 39, 40, 57, 58, 59, 60, 67, 68, 69, 70])
  assert.deepEqual(planned.map((p) => p.when), [1002, 1003, 1004, 1005, 1022, 1023, 1024, 1025, 1032, 1033, 1034, 1035])
})

test("a cue just behind the clock (within 0.05 s) still plays; older ones do not", () => {
  const cues = [{ at: 9.96, type: "tick" }, { at: 9.9, type: "tick" }, { at: 10, type: "boundary", sound: "beep" }]
  assert.deepEqual(planCues(cues, 10, 0).map((p) => p.cue.at), [9.96, 10])
})

test("a breathing tone that has already started is not replayed partway", () => {
  const box = new Timeline({ kind: "breathing", settings: BOX, rounds: 1, prepSeconds: 0 })
  const planned = planCues(cueSchedule(box, BREATHING_SOUND), 1, 50)
  assert.deepEqual(planned.filter((p) => p.cue.type === "breathe").map((p) => [p.cue.role, p.when]), [
    ["hold", 53], ["exhale", 57], ["hold", 61],
  ])
})
