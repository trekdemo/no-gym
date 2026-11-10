import { Controller } from "@hotwired/stimulus"
import { parseExercises, formatExercises } from "nogym/format"

// EMOM "Paste as text" and "Copy exercises as text" (spec 10.3). Lives on the
// same element as the rows controller that holds the exercises.
export default class extends Controller {
  static targets = ["text", "replace", "copy"]

  toggle() {
    this.replaceTarget.disabled = this.textTarget.value.trim() === ""
  }

  replace() {
    const exercises = parseExercises(this.textTarget.value)
    if (!exercises.length) return
    this.rows.replace(exercises.map(({ name, reps }) => ({ name, reps: reps ?? "" })))
  }

  async copy() {
    const exercises = this.rows.values().map(({ name, reps }) => ({ name, reps: reps === "" ? null : Number(reps) }))
    try {
      await navigator.clipboard.writeText(formatExercises(exercises))
    } catch {
      return
    }
    const button = this.copyTarget
    const label = button.dataset.label ?? button.textContent
    button.dataset.label = label
    button.textContent = "Copied!"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => (button.textContent = label), 1500)
  }

  get rows() {
    return this.application.getControllerForElementAndIdentifier(this.element, "rows")
  }
}
