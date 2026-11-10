import { Controller } from "@hotwired/stimulus"

// − and + buttons around a number field. With `coarse`, it steps by 1 below 10 and by 5 from 10.
export default class extends Controller {
  static targets = ["input"]
  static values = { min: Number, max: Number, step: { type: Number, default: 1 }, coarse: Boolean }

  up() {
    const value = this.current
    this.set(value + (this.coarseValue ? (value < 10 ? 1 : 5) : this.stepValue))
  }

  down() {
    const value = this.current
    this.set(value - (this.coarseValue ? (value <= 10 ? 1 : 5) : this.stepValue))
  }

  get current() {
    return Number(this.inputTarget.value) || 0
  }

  set(value) {
    const clamped = Math.min(this.maxValue, Math.max(this.minValue, Math.round(value * 1000) / 1000))
    this.inputTarget.value = clamped
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
