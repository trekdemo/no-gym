// A sequence laid out in time (spec 6): the prep, then every interval of every
// round. Times are seconds from the start of the run, prep included.
import { intervals } from "nogym/template"

export class Timeline {
  // sequence: { kind, settings, rounds, prepSeconds }
  constructor({ kind, settings, rounds, prepSeconds }) {
    this.prepDuration = Math.max(0, Number(prepSeconds) || 0)
    this.rounds = Math.max(0, Math.trunc(Number(rounds) || 0))
    this.steps = []
    this.stepsPerRound = 0
    let time = this.prepDuration
    for (let round = 0; round < this.rounds; round++) {
      const list = intervals(kind, settings || {}, round)
      this.stepsPerRound = Math.max(this.stepsPerRound, list.length)
      list.forEach((interval, indexInRound) => {
        const length = Math.max(0, interval.seconds)
        this.steps.push({ round: round + 1, indexInRound, interval, start: time, end: time + length })
        time += length
      })
    }
  }

  // The end of the last step, or the prep length if there are no steps.
  get duration() {
    return this.steps.length ? this.steps[this.steps.length - 1].end : this.prepDuration
  }

  // Everything but the prep.
  get workDuration() {
    return this.duration - this.prepDuration
  }

  isLastInRound(index) {
    return index === this.steps.length - 1 || this.steps[index + 1].round !== this.steps[index].round
  }

  // The step running at `elapsed`, by binary search; -1 during prep or after the end.
  // A boundary moment belongs to the next step.
  stepIndexAt(elapsed) {
    if (elapsed < this.prepDuration || elapsed >= this.duration || !this.steps.length) return -1
    let low = 0
    let high = this.steps.length - 1
    while (low < high) {
      const mid = Math.floor((low + high + 1) / 2)
      if (this.steps[mid].start <= elapsed) low = mid
      else high = mid - 1
    }
    return low
  }
}
