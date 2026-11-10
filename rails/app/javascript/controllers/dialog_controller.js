import { Controller } from "@hotwired/stimulus"

// A <dialog> that can open itself when it appears, like the "Can't save yet" alert.
export default class extends Controller {
  static values = { open: Boolean }

  connect() {
    if (this.openValue && !this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }
}
