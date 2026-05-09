import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["field", "status"]
  static values  = { url: String, param: String }

  save(event) {
    const field = event.target
    const csrfToken = document.querySelector("[name='csrf-token']")?.content
    const body = field.type === "file" && field.form ? new FormData(field.form) : new FormData()

    if (!body.has("_method")) body.append("_method", "patch")

    if (field.type === "file") {
      if (field.files[0]) body.set(this.paramValue, field.files[0])
    } else {
      body.append(this.paramValue, field.type === "checkbox" ? field.checked : field.value)
    }

    if (csrfToken && !body.has("authenticity_token")) body.append("authenticity_token", csrfToken)

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
