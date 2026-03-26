import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "section"]

  #observer = null

  connect() {
    this.#observer = new IntersectionObserver(
      (entries) => this.#handleIntersection(entries),
      { rootMargin: "-80px 0px -70% 0px", threshold: 0 }
    )

    this.sectionTargets.forEach((section) => this.#observer.observe(section))
  }

  disconnect() {
    this.#observer?.disconnect()
  }

  #handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        const sectionId = entry.target.dataset.section
        this.#activateLink(sectionId)
      }
    })
  }

  #activateLink(sectionId) {
    this.linkTargets.forEach((link) => {
      if (link.dataset.section === sectionId) {
        link.classList.add("toc-link--active")
      } else {
        link.classList.remove("toc-link--active")
      }
    })
  }
}
