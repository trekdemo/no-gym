import { Controller } from "@hotwired/stimulus"
import { Timeline } from "nogym/timeline"
import { clock, duration } from "nogym/format"

// Keeps the editor's total time (and the breathing header) live while the user edits.
export default class extends Controller {
  static targets = ["total", "breathTotal", "preset"]
  static values = { kind: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const settings = this.settings()
    const timeline = new Timeline({
      kind: this.kindValue, settings, rounds: this.number("rounds"), prepSeconds: this.number("prepSeconds"),
    })
    if (this.hasTotalTarget) this.totalTarget.textContent = clock(timeline.workDuration)

    if (this.kindValue === "breathing") {
      const keys = ["inhale", "holdIn", "exhale", "holdOut"]
      this.breathTotalTarget.textContent = duration(keys.reduce((sum, key) => sum + settings[key], 0))
      for (const chip of this.presetTargets) {
        const values = JSON.parse(chip.dataset.values)
        chip.setAttribute("aria-pressed", keys.every((key) => values[key] === settings[key]))
      }
    }
  }

  preset(event) {
    const values = JSON.parse(event.currentTarget.dataset.values)
    for (const [key, value] of Object.entries(values)) this.field(key).value = value
    this.refresh()
  }

  // Reads the kind's settings from the form, in the same shape the server stores.
  settings() {
    switch (this.kindValue) {
      case "emom":
        return {
          stepSeconds: this.number("stepSeconds"),
          exercises: this.rows().map((row) => ({ name: this.value("name", row), reps: this.value("reps", row) })),
        }
      case "tabata":
        return {
          workSeconds: this.number("workSeconds"),
          restSeconds: this.number("restSeconds"),
          exercises: this.value("exercisesText").split(/\r?\n/),
        }
      case "breathing":
        return Object.fromEntries(["inhale", "holdIn", "exhale", "holdOut"].map((key) => [key, this.number(key)]))
      case "custom":
        return {
          intervals: this.rows().map((row) => ({
            label: this.value("label", row), seconds: this.number("seconds", row),
            role: this.value("role", row), reps: this.value("reps", row),
          })),
        }
      default:
        return {}
    }
  }

  rows() {
    return [...this.element.querySelectorAll('[data-rows-target="row"]')]
  }

  field(name, root = this.element) {
    return root.querySelector(`[data-field="${name}"]`)
  }

  value(name, root) {
    return this.field(name, root)?.value ?? ""
  }

  number(name, root) {
    return Number(this.value(name, root)) || 0
  }
}
