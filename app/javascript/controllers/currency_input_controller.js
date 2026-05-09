import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  format() {
    let val = this.element.value.replace(/[^0-9,.-]/g, "").replace(",", ".")
    this.element.value = val
  }
}
