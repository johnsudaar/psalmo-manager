import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "status"]
  static values  = { url: String, param: String }

  save(event) {
    const field = event.target
    const body  = new FormData()
    body.append("_method", "patch")
    body.append(this.paramValue, field.type === "checkbox" ? field.checked : field.value)

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
  }
}
