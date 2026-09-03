import { Controller } from "@hotwired/stimulus"

// Briefly highlights the dashboard counts whenever they are replaced by a
// Turbo Stream broadcast, so the "real-time" update is actually noticeable.
export default class extends Controller {
  static classes = ["highlight"]

  connect() {
    this.element.classList.add(...this.highlightClasses)
    this.timeout = setTimeout(() => {
      this.element.classList.remove(...this.highlightClasses)
    }, 700)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
