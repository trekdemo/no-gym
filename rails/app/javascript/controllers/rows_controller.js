import { Controller } from "@hotwired/stimulus"

// An editable list of rows: add, delete and reorder (EMOM exercises, custom intervals).
export default class extends Controller {
  static targets = ["list", "template", "row"]
  // Fields that a new row copies from the last row, such as a custom interval's duration and role.
  static values = { copy: Array }

  add() {
    const last = this.rowTargets.at(-1)
    const copied = Object.fromEntries(
      last ? this.copyValue.map((field) => [field, last.querySelector(`[data-field="${field}"]`).value]) : [],
    )
    const row = this.build(copied)
    this.listTarget.append(row)
    row.querySelector('input[type="text"]')?.focus()
    this.changed()
  }

  // Swaps every row for new ones built from `items`, a list of { field: value }.
  replace(items) {
    this.rowTargets.forEach((row) => row.remove())
    for (const item of items) this.listTarget.append(this.build(item))
    this.changed()
  }

  values() {
    return this.rowTargets.map((row) =>
      Object.fromEntries([...row.querySelectorAll("[data-field]")].map((el) => [el.dataset.field, el.value])),
    )
  }

  remove(event) {
    this.rowFor(event).remove()
    this.changed()
  }

  up(event) {
    const row = this.rowFor(event)
    if (row.previousElementSibling) row.previousElementSibling.before(row)
    this.changed()
  }

  down(event) {
    const row = this.rowFor(event)
    if (row.nextElementSibling) row.nextElementSibling.after(row)
    this.changed()
  }

  // Reps fields take digits only.
  digits(event) {
    const input = event.target
    const clean = input.value.replace(/\D/g, "")
    if (clean !== input.value) input.value = clean
  }

  build(values = {}) {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)
    for (const [field, value] of Object.entries(values)) {
      const input = row.querySelector(`[data-field="${field}"]`)
      if (input) input.value = value ?? ""
    }
    return row
  }

  rowFor(event) {
    return event.currentTarget.closest('[data-rows-target="row"]')
  }

  changed() {
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
