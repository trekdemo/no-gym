import { Controller } from "@hotwired/stimulus"
import { audio } from "nogym/audio"

// Browsers only start audio from a user gesture, so the tap on ▶ Start unlocks
// it before Turbo shows the run screen (spec 14).
export default class extends Controller {
  unlock() {
    audio.unlock()
  }
}
