import { Controller } from "@hotwired/stimulus"

// Toggles the mobile nav menu, shown collapsed behind a "Menu" button below
// the sm breakpoint and always expanded above it (see layouts/_nav).
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    const expanded = this.menuTarget.classList.toggle("flex")
    this.menuTarget.classList.toggle("hidden", !expanded)
    this.buttonTarget.setAttribute("aria-expanded", expanded)
  }
}
