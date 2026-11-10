import { Controller } from "@hotwired/stimulus"
import { Timeline } from "nogym/timeline"
import { RunClock } from "nogym/clock"
import { cueSchedule } from "nogym/cues"
import { breathScale } from "nogym/breath"
import { clock, duration, summary } from "nogym/format"
import { displayLabel, isBreathing } from "nogym/template"
import { audio } from "nogym/audio"

const now = () => performance.now() / 1000

// The run screen (spec 10.5, 11). Everything on it is computed from the clock
// on every animation frame; the sounds are scheduled ahead on the audio clock.
export default class extends Controller {
  static targets = [
    "screen", "paused", "meta", "role", "label", "circle", "countdown", "bar",
    "nextCaption", "nextLabel", "nextDuration", "playButton", "soundHint", "done", "stopDialog",
  ]
  static values = { sequence: Object }

  connect() {
    const sequence = this.sequenceValue
    this.sound = sequence.sound
    this.timeline = new Timeline(sequence)
    this.cues = cueSchedule(this.timeline, this.sound)
    this.clock = new RunClock(now())
    this.lastStep = null
    this.finished = false
    this.shown = {}

    this.onVisibility = () => this.visibilityChanged()
    document.addEventListener("visibilitychange", this.onVisibility)
    this.startAudio()
    this.requestWakeLock()
    this.frame()
  }

  // Leaving the screen in any way ends the run (spec 11).
  disconnect() {
    cancelAnimationFrame(this.raf)
    clearTimeout(this.doneTimer)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.audioContext?.removeEventListener?.("statechange", this.onAudioState)
    if (!this.finished) {
      audio.clear()
      audio.stopAfter(0)
    }
    this.releaseWakeLock()
  }

  // Controls

  toggle() {
    if (this.finished) return
    if (this.clock.isPaused) {
      this.clock.resume(now())
      this.reschedule()
    } else {
      this.clock.pause(now())
      audio.clear()
    }
  }

  next() {
    this.skip(() => this.clock.skipForward(this.timeline, now()))
  }

  previous() {
    this.skip(() => this.clock.skipBackward(this.timeline, now()))
  }

  confirmStop() {
    this.stopDialogTarget.showModal()
  }

  keepGoing() {
    this.stopDialogTarget.close()
  }

  key(event) {
    if (this.finished || this.stopDialogTarget.open || event.target.closest?.("input, textarea, select")) return
    const actions = { " ": () => this.toggle(), ArrowRight: () => this.next(), ArrowLeft: () => this.previous(), Escape: () => this.confirmStop() }
    const action = actions[event.key]
    if (action) {
      event.preventDefault()
      action()
    }
  }

  // A tap after a reload, when the browser kept audio locked.
  enableSound() {
    audio.unlock()
    this.soundHintTarget.hidden = true
  }

  // Internals

  skip(move) {
    if (this.finished) return
    move()
    // No vibration after a manual skip.
    this.lastStep = this.clock.position(this.timeline, now()).stepIndex
    this.reschedule()
  }

  startAudio() {
    this.audioContext = audio.unlock()
    if (!this.audioContext) return
    audio.setVolume(this.sound.volume ?? 0.8)
    // Covers the first unlock, and coming back after an interruption such as a call.
    this.onAudioState = () => {
      if (audio.running) {
        this.soundHintTarget.hidden = true
        this.reschedule()
      }
    }
    this.audioContext.addEventListener?.("statechange", this.onAudioState)
    if (audio.running) {
      this.reschedule()
    } else if (this.cues.length) {
      this.soundHintTarget.hidden = false
    }
  }

  reschedule() {
    if (this.finished || this.clock.isPaused) return audio.clear()
    audio.schedule(this.cues, this.clock.elapsed(now()))
  }

  visibilityChanged() {
    if (document.visibilityState !== "visible") return
    this.requestWakeLock()
    if (!this.finished && this.audioContext && !audio.running) audio.unlock()
  }

  async requestWakeLock() {
    if (this.finished || !("wakeLock" in navigator) || this.wakeLock) return
    try {
      this.wakeLock = await navigator.wakeLock.request("screen")
      this.wakeLock.addEventListener("release", () => (this.wakeLock = null))
    } catch {
      this.wakeLock = null
    }
  }

  releaseWakeLock() {
    this.wakeLock?.release().catch(() => {})
    this.wakeLock = null
  }

  frame() {
    const position = this.clock.position(this.timeline, now())
    this.render(position)
    this.vibrate(position)
    if (position.phase === "done") return this.finish()
    this.raf = requestAnimationFrame(() => this.frame())
  }

  // One strong pulse when the step changes on its own, if haptics is on.
  vibrate(position) {
    if (this.lastStep !== null && position.stepIndex !== this.lastStep && position.phase === "active" && this.sound.haptics) {
      navigator.vibrate?.(200)
    }
    this.lastStep = position.stepIndex
  }

  finish() {
    this.finished = true
    this.releaseWakeLock()
    // Let the finish sound ring out, then stop audio.
    audio.stopAfter(3)
    this.doneTimer = setTimeout(() => {
      this.screenTarget.hidden = true
      this.doneTarget.hidden = false
    }, 700)
  }

  render(position) {
    const { phase, stepIndex } = position
    const { steps, rounds, stepsPerRound, workDuration } = this.timeline
    const step = phase === "active" ? steps[stepIndex] : null
    const next = phase === "done" ? null : steps[stepIndex + 1]
    const role = step ? step.interval.role : "prep"

    this.show("role", role, (value) => (this.element.dataset.role = value))
    this.show("meta", step ? `Round ${step.round} of ${rounds} · Step ${step.indexInRound + 1} of ${stepsPerRound}` : summary(rounds, workDuration))
    this.show("role", step ? role.toUpperCase() : "GET READY")
    this.show("label", phase === "prep" ? "Get ready" : phase === "done" ? "Done" : displayLabel(step.interval), (text) => this.changeLabel(text))
    this.show("countdown", clock(position.remaining))
    this.show("nextCaption", phase === "prep" ? "FIRST" : "NEXT")
    this.show("nextLabel", next ? displayLabel(next.interval) : "Last one!")
    this.show("nextDuration", next ? duration(next.end - next.start) : "")
    this.show("paused", this.clock.isPaused, (paused) => {
      this.pausedTarget.hidden = !paused
      this.element.classList.toggle("is-paused", paused)
      this.playButtonTarget.textContent = paused ? "▶" : "⏸"
      this.playButtonTarget.setAttribute("aria-label", paused ? "Resume" : "Pause")
    })
    this.show("final", phase === "active" && position.displaySeconds <= 3, (final) => this.element.classList.toggle("is-final", final))
    this.barTarget.style.transform = `scaleX(${position.fraction})`

    const breathing = step !== null && isBreathing(role)
    this.show("circle", breathing, (visible) => (this.circleTarget.hidden = !visible))
    if (breathing) this.circleTarget.style.setProperty("--scale", breathScale(this.timeline, stepIndex, position.fraction))
  }

  // Writes to the page only when a value changes. Text values go to the target of the same name.
  show(name, value, apply) {
    const key = apply ? `${name}:fn` : name
    if (this.shown[key] === value) return
    this.shown[key] = value
    if (apply) apply(value)
    else this[`${name}Target`].textContent = value
  }

  // The current label cross-fades and shrinks to fit up to 3 lines.
  changeLabel(text) {
    const label = this.labelTarget
    label.textContent = text
    label.classList.remove("fade-in")
    void label.offsetWidth
    label.classList.add("fade-in")
    label.style.fontSize = ""
    let size = parseFloat(getComputedStyle(label).fontSize)
    const lineHeight = parseFloat(getComputedStyle(label).lineHeight) / size || 1.1
    while (size > 20 && label.scrollHeight > size * lineHeight * 3 + 2) {
      size -= 2
      label.style.fontSize = `${size}px`
    }
  }
}
