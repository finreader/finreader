import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    const saved = localStorage.getItem(this.storageKey)
    if (saved) {
      window.scrollTo(0, parseInt(saved, 10))
    }

    this.save = this.save.bind(this)
    window.addEventListener("scroll", this.save, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.save)
  }

  save() {
    localStorage.setItem(this.storageKey, window.scrollY)
  }

  get storageKey() {
    return `scroll:${this.keyValue}`
  }
}
