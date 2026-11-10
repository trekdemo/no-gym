// Plays cues on the Web Audio clock (spec 8.5, 14). Cues are scheduled ahead
// with AudioBufferSourceNode.start(when), not fired by UI timers, so they stay
// on time while the page is busy or throttled.
import { planCues } from "nogym/cues"
import { samples, countdownTick, breath } from "nogym/synth"

const defaultContext = () => {
  const AudioContext = globalThis.AudioContext || globalThis.webkitAudioContext
  return AudioContext ? new AudioContext() : null
}

export class CuePlayer {
  constructor(createContext = defaultContext) {
    this.createContext = createContext
    this.context = null
    this.pending = new Set()
    this.buffers = new Map()
    this.closeTimer = null
  }

  // Browsers only start audio after a user gesture: call this from a tap.
  unlock() {
    clearTimeout(this.closeTimer)
    if (!this.context) {
      this.context = this.createContext()
      if (!this.context) return null
      this.master = this.context.createGain()
      this.master.connect(this.context.destination)
      // Separate channels, so a long breathing tone never delays a tick.
      this.channels = {}
      for (const name of ["tick", "boundary", "breathe"]) {
        this.channels[name] = this.context.createGain()
        this.channels[name].connect(this.master)
      }
    }
    if (this.context.state !== "running") this.context.resume?.()
    return this.context
  }

  get running() {
    return this.context?.state === "running"
  }

  setVolume(volume) {
    if (this.master) this.master.gain.value = Math.min(1, Math.max(0, volume))
  }

  // Clears every pending cue, then schedules each cue still to come relative to `elapsed`.
  schedule(cues, elapsed) {
    this.clear()
    if (!this.context) return []
    const now = this.context.currentTime
    const planned = planCues(cues, elapsed, now)
    for (const { cue, when } of planned) this.play(cue, Math.max(now, when))
    return planned
  }

  clear() {
    for (const source of this.pending) {
      try {
        source.stop()
      } catch {
        // Already stopped.
      }
      source.disconnect?.()
    }
    this.pending.clear()
  }

  // Keeps audio running for a while (so the finish sound rings out), then suspends it.
  stopAfter(seconds) {
    clearTimeout(this.closeTimer)
    this.closeTimer = setTimeout(() => {
      this.clear()
      this.context?.suspend?.()
    }, seconds * 1000)
  }

  play(cue, when) {
    const buffer = this.bufferFor(cue)
    if (!buffer) return null
    const source = this.context.createBufferSource()
    source.buffer = buffer
    source.connect(this.channels[cue.type] || this.master)
    source.onended = () => this.pending.delete(source)
    source.start(when)
    this.pending.add(source)
    return source
  }

  // Previews for the editor's sound settings.
  preview(choice, volume) {
    if (!this.unlock()) return
    if (volume != null) this.setVolume(volume)
    this.play({ type: "boundary", sound: choice }, this.context.currentTime)
  }

  previewTick(volume) {
    if (!this.unlock()) return
    if (volume != null) this.setVolume(volume)
    this.play({ type: "tick" }, this.context.currentTime)
  }

  previewBreath(role, volume) {
    if (!this.unlock()) return
    if (volume != null) this.setVolume(volume)
    this.play({ type: "breathe", role, duration: 4 }, this.context.currentTime)
  }

  bufferFor(cue) {
    const key = cue.type === "tick" ? "tick" : cue.type === "breathe" ? `breathe:${cue.role}:${cue.duration}` : cue.sound
    if (this.buffers.has(key)) return this.buffers.get(key)
    const rate = this.context.sampleRate
    const data =
      cue.type === "tick" ? countdownTick(rate) : cue.type === "breathe" ? breath(cue.role, cue.duration, rate) : samples(cue.sound, rate)
    if (!data.length) return null
    const buffer = this.context.createBuffer(1, data.length, rate)
    buffer.getChannelData(0).set(data)
    this.buffers.set(key, buffer)
    return buffer
  }
}

// One player for the whole page, so the context unlocked by the tap on
// "Start" in the list is still there after Turbo shows the run screen.
export const audio = new CuePlayer()
