import { test } from "node:test"
import assert from "node:assert/strict"
import { CuePlayer } from "nogym/audio"
import { cueSchedule } from "nogym/cues"
import { tabataTimeline, DEFAULT_SOUND } from "./helpers.js"

// A stand-in for the Web Audio API that records what gets scheduled.
class FakeContext {
  constructor() {
    this.state = "suspended"
    this.currentTime = 0
    this.sampleRate = 8000
    this.destination = {}
    this.sources = []
  }
  resume() { this.state = "running" }
  suspend() { this.state = "suspended" }
  createGain() { return { gain: { value: 1 }, connect() {} } }
  createBuffer(channels, length, rate) {
    const data = new Float32Array(length)
    return { length, sampleRate: rate, getChannelData: () => data }
  }
  createBufferSource() {
    const source = {
      startedAt: null, stopped: false, output: null,
      connect(node) { this.output = node },
      disconnect() {},
      start(when) { this.startedAt = when },
      stop() { this.stopped = true },
    }
    this.sources.push(source)
    return source
  }
}

function setup(currentTime) {
  const context = new FakeContext()
  context.currentTime = currentTime
  const player = new CuePlayer(() => context)
  player.unlock()
  return { context, player }
}

const cues = cueSchedule(tabataTimeline(), DEFAULT_SOUND)

test("unlock creates and resumes the audio context", () => {
  const { context, player } = setup(0)
  assert.equal(context.state, "running")
  assert.equal(player.running, true)
})

test("on start every cue is scheduled on the audio clock", () => {
  const { context, player } = setup(42)
  player.schedule(cues, 0)
  assert.equal(context.sources.length, cues.length)
  assert.deepEqual(context.sources.map((s) => s.startedAt), cues.map((c) => 42 + c.at))
})

test("ticks, boundary sounds and breathing tones use separate channels", () => {
  const { context, player } = setup(0)
  player.schedule([{ at: 1, type: "tick" }, { at: 1, type: "boundary", sound: "bell" }, { at: 1, type: "breathe", role: "inhale", duration: 4 }], 0)
  const outputs = context.sources.map((s) => s.output)
  assert.equal(new Set(outputs).size, 3)
  assert.deepEqual(outputs, [player.channels.tick, player.channels.boundary, player.channels.breathe])
})

test("resume clears the pending cues and schedules the rest from the current elapsed time", () => {
  const { context, player } = setup(10)
  player.schedule(cues, 0)
  const first = [...context.sources]
  context.currentTime = 200
  player.schedule(cues, 35)
  assert.ok(first.every((s) => s.stopped), "old cues are stopped")
  const fresh = context.sources.slice(first.length)
  assert.deepEqual(fresh.map((s) => s.startedAt), [202, 203, 204, 205, 222, 223, 224, 225, 232, 233, 234, 235])
})

test("pause clears every pending cue", () => {
  const { context, player } = setup(0)
  player.schedule(cues, 0)
  player.clear()
  assert.ok(context.sources.every((s) => s.stopped))
  assert.equal(player.pending.size, 0)
})

test("a cue just behind the clock plays now, not in the past", () => {
  const { context, player } = setup(5)
  player.schedule([{ at: 9.97, type: "boundary", sound: "beep" }], 10)
  assert.equal(context.sources[0].startedAt, 5)
})

test("a sound of none schedules nothing", () => {
  const { context, player } = setup(0)
  player.play({ type: "boundary", sound: "none" }, 1)
  assert.equal(context.sources.length, 0)
})

test("buffers are made once per sound", () => {
  const { player } = setup(0)
  player.schedule(cues, 0)
  assert.deepEqual([...player.buffers.keys()].sort(), ["beep", "bell", "double_beep", "tick"])
})

test("without Web Audio the player does nothing", () => {
  const player = new CuePlayer(() => null)
  assert.equal(player.unlock(), null)
  assert.deepEqual(player.schedule(cues, 0), [])
})
