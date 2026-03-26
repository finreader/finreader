import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "panel"]

  connect() {
    this.currentAbortController = null
    this.currentFocusIndex = -1
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
    this.currentAbortController?.abort()
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closePanel()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.closePanel()
      this.inputTarget.blur()
      this.currentFocusIndex = -1
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.navigateDown()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.navigateUp()
    } else if (event.key === "Enter") {
      event.preventDefault()
      const focusables = this.getFocusableElements()
      if (this.currentFocusIndex >= 0 && focusables[this.currentFocusIndex]) {
        focusables[this.currentFocusIndex].click()
      }
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    this.currentFocusIndex = -1

    this.currentAbortController?.abort()
    this.currentAbortController = null

    clearTimeout(this.searchTimeout)

    if (query.length === 0) {
      this.clearResults()
      this.closePanel()
      return
    }

    this.showLoading()
    this.openPanel()

    this.searchTimeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  performSearch(query) {
    const abortController = new AbortController()
    this.currentAbortController = abortController

    const url = `/search?query=${encodeURIComponent(query)}`

    fetch(url, {
      signal: abortController.signal,
      headers: {
        "Accept": "text/html"
      }
    })
    .then(response => response.text())
    .then(html => {
      if (this.currentAbortController === abortController &&
          this.hasInputTarget &&
          this.inputTarget.value.trim().length > 0) {
        this.resultsTarget.innerHTML = html
        this.openPanel()
      }
      if (this.currentAbortController === abortController) {
        this.currentAbortController = null
      }
    })
    .catch(error => {
      if (error.name !== "AbortError") {
        console.error("Search failed:", error)
      }
      if (this.currentAbortController === abortController) {
        this.currentAbortController = null
      }
    })
  }

  navigateDown() {
    const focusables = this.getFocusableElements()
    this.currentFocusIndex = Math.min(this.currentFocusIndex + 1, focusables.length - 1)
    this.updateHighlight(focusables)
  }

  navigateUp() {
    const focusables = this.getFocusableElements()
    this.currentFocusIndex = Math.max(this.currentFocusIndex - 1, 0)
    this.updateHighlight(focusables)
  }

  getFocusableElements() {
    return Array.from(this.resultsTarget.querySelectorAll("a[data-search-result]"))
  }

  updateHighlight(focusables) {
    focusables.forEach(el => el.classList.remove("bg-stone-100"))
    if (this.currentFocusIndex >= 0 && focusables[this.currentFocusIndex]) {
      focusables[this.currentFocusIndex].classList.add("bg-stone-100")
      focusables[this.currentFocusIndex].scrollIntoView({ block: "nearest" })
    }
  }

  showLoading() {
    this.resultsTarget.innerHTML = `
      <div class="px-5 py-4 text-stone-400 text-sm flex items-center gap-2">
        <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Searching...</span>
      </div>
    `
  }

  clearResults() {
    this.resultsTarget.innerHTML = ""
  }

  openPanel() {
    this.panelTarget.classList.remove("hidden")
  }

  closePanel() {
    this.panelTarget.classList.add("hidden")
    this.currentFocusIndex = -1
  }
}
