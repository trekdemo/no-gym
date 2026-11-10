import { Controller } from "@hotwired/stimulus"
import { audio } from "nogym/audio"

// Plays a sound as soon as it is picked in the sound settings (spec 10.4).
export default class extends Controller {
  static targets = ["volume", "intervalEnd"]

  choice(event) {
    audio.preview(event.target.value, this.level)
  }

  tick() {
    audio.previewTick(this.level)
  }

  breath(event) {
    audio.previewBreath(event.params.role, this.level)
  }

  // Letting go of the slider plays the interval-end sound, or a beep if that is None.
  volume() {
    const choice = this.intervalEndTarget.value
    audio.preview(choice === "none" ? "beep" : choice, this.level)
  }

  get level() {
    return Number(this.volumeTarget.value)
  }
}
