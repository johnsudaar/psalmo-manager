import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    const field = event.target
    if (!field.files || field.files.length === 0 || !field.form) return

    field.form.requestSubmit()
  }
}
