import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  toggle() {
    const section = this.element
    const collapsed = section.classList.toggle("section-collapsed")
    this.buttonTarget.textContent = collapsed ? "Show" : "Hide"
  }
}
