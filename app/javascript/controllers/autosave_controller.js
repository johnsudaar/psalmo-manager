import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["field", "status"]
  static values  = { url: String, param: String }

  save(event) {
    const field = event.target
    const body  = new FormData()
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    body.append("_method", "patch")
    body.append(this.paramValue, field.type === "checkbox" ? field.checked : field.value)
    if (csrfToken) body.append("authenticity_token", csrfToken)

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
      },
      credentials: "same-origin",
      body
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
    .catch(error => console.error("Autosave failed", error))
  }
}
