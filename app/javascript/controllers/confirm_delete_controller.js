import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  confirm(event) {
    if (!window.confirm(this.element.dataset.confirmMessage || "Êtes-vous sûr(e) ?")) {
      event.preventDefault()
    }
  }
}
