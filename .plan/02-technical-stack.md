# 02 — Technical Stack

## Overview

| Layer | Choice | Version |
|---|---|---|
| Language | Ruby | 3.3.x |
| Framework | Ruby on Rails | 7.2.x |
| Database | PostgreSQL | 16 |
| Background jobs | Sidekiq | 7.x |
| Job scheduler | sidekiq-cron | 1.x |
| Cache / queue broker | Redis | 7 |
| Frontend | Hotwire (Turbo + Stimulus) | ships with Rails 7.2 |
| CSS | Tailwind CSS | 3.x (via `tailwindcss-rails`) |
| JS bundler | Importmap | ships with Rails 7.2 |
| Authentication | Devise | 4.9.x |
| HTTP client | Faraday | 2.x |
| PDF generation | Prawn + prawn-table | 2.x |
| Charts | Chartkick + Groupdate | 4.x / 6.x |
| Pagination | Pagy | 9.x |
| Testing | RSpec-Rails | 7.x |
| Factories | FactoryBot Rails | 6.x |
| Fake data | Faker | 3.x |
| HTTP mocking | WebMock + VCR | latest |
| Actor pattern | Interactor | 3.x |
| Audit log | PaperTrail | 15.x |
| Linter | RuboCop Rails Omakase | latest |

---

## Infrastructure

### docker-compose.yml (development)

Two services are required locally:

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: psalmo
      POSTGRES_PASSWORD: psalmo
      POSTGRES_DB: psalmo_manager_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

### Production

- Single server (VPS or equivalent)
- Puma as the web server (Rails default)
- Sidekiq as a separate process (`bundle exec sidekiq`)
- Nginx as reverse proxy (not managed by this repo)
- PostgreSQL and Redis on the same host or managed services
- Environment variables via `.env` (not committed); loaded by `dotenv-rails` in development

---

## Gem Details and Rationale

### Core Rails
```ruby
gem "rails", "~> 7.2"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"  # for any JSON API responses (webhooks ack, etc.)
```

### Authentication
```ruby
gem "devise"
```
Admin-only. No self-registration. `User` model (or `AdminUser`). All routes protected with
`before_action :authenticate_user!` in `ApplicationController`.

### Background Jobs
```ruby
gem "sidekiq"
gem "sidekiq-cron"
```
- Sidekiq uses Redis for its queue.
- `sidekiq-cron` schedules the HelloAsso sync job to run every 30 minutes.
- Sidekiq Web UI mounted at `/sidekiq` (protected by Devise).
- Config lives in `config/sidekiq.yml` and `config/initializers/sidekiq.rb`.

### HTTP Client (HelloAsso API)
```ruby
gem "faraday"
gem "faraday-retry"
```
- `Faraday::Retry` middleware handles transient 5xx errors automatically.
- A custom middleware handles token refresh (OAuth2 client-credentials).
- Base URL and credentials come from environment variables.

### PDF Generation
```ruby
gem "prawn"
gem "prawn-table"
```
- Used exclusively for the "Fiche d'indemnisation animateur" PDF and workshop roster PDFs.
- PDFs are generated on-demand (no pre-generation or storage) and streamed to the browser.
- See `.plan/07-pdf-fiche-indemnisation.md` for the layout spec.

### Charts
```ruby
gem "chartkick"
gem "groupdate"
```
- Chartkick renders charts as `<canvas>` elements using Chart.js (loaded via Importmap CDN).
- Groupdate enables `group_by_week`, `group_by_day` etc. directly on ActiveRecord relations.

### Pagination
```ruby
gem "pagy"
```
- Used on all list views (participants, orders, staff).
- Pagy is significantly faster than Kaminari or will_paginate for large datasets.
- Include `Pagy::Backend` in `ApplicationController` and `Pagy::Frontend` in
  `ApplicationHelper`.

### Actor Pattern
```ruby
gem "interactor"
```
Every meaningful user-initiated action (creating a workshop substitution, updating a staff profile
field, triggering a manual sync) is handled by a dedicated actor class in `app/actors/`.

**Why Interactor?**
Controllers must stay thin. Interactor provides a lightweight, standardised `call` / `context`
protocol without the overhead of a service-object framework. The `organizer` feature lets complex
flows (e.g. sync → update stats) be composed from smaller actors.

**Convention**:
- One actor per user action: `Actors::ApplyWorkshopSubstitution`, `Actors::UpdateStaffField`, etc.
- Actor lives in `app/actors/<namespace>/<action>.rb`
- Controller calls actor, checks `context.success?`, renders inline error or redirects/streams
- Actors never render; they only mutate `context`

**Example**:
```ruby
# app/actors/apply_workshop_substitution.rb
class Actors::ApplyWorkshopSubstitution
  include Interactor

  def call
    registration = context.registration
    workshop     = context.workshop
    slot         = context.time_slot

    existing = registration.registration_workshops.find_by(
      workshop: Workshop.where(time_slot: slot, edition: registration.edition)
    )
    existing&.destroy

    rw = registration.registration_workshops.build(
      workshop: workshop,
      price_paid_cents: workshop.base_price_cents,
      is_override: true
    )
    context.fail!(error: rw.errors.full_messages.to_sentence) unless rw.save
    context.registration_workshop = rw
  end
end
```

**Controller usage**:
```ruby
result = Actors::ApplyWorkshopSubstitution.call(
  registration: @registration, workshop: @workshop, time_slot: @time_slot
)
if result.success?
  redirect_to @registration, notice: "Changement enregistré."
else
  render :new, status: :unprocessable_entity, locals: { error: result.error }
end
```

---

### Audit Log
```ruby
gem "paper_trail"
```
PaperTrail tracks every change to every model. A `versions` table is created by the PaperTrail
generator. `whodunnit` is set to `current_user.email` in `ApplicationController`.

**Configuration**:
```ruby
# config/initializers/paper_trail.rb
PaperTrail.config.track_associations = false  # keep it simple
```

```ruby
# app/controllers/application_controller.rb
before_action :set_paper_trail_whodunnit

def user_for_paper_trail
  current_user&.email
end
```

**Model usage** — add to every model:
```ruby
has_paper_trail skip: [:updated_at], skip_unchanged: true
```

`skip_unchanged: true` ensures that a HelloAsso sync that touches a record but makes no actual
change does not create a noise version entry.

**Override fields are tracked**: changes to `excluded_from_stats`, `is_unaccompanied_minor`,
`responsible_person_note`, and `registration_workshops` with `is_override: true` are all tracked
by PaperTrail — including changes made by the sync service.

---

### Money
No money gem is used. All amounts are stored as **integer cents** in the database. A simple
helper formats them for display:

```ruby
# app/helpers/application_helper.rb
def format_euros(cents)
  return "—" if cents.nil?
  "#{format('%.2f', cents / 100.0).gsub('.', ',')} €"
end
```

### Development / Test
```ruby
group :development, :test do
  gem "dotenv-rails"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "webmock"
  gem "vcr"
  gem "shoulda-matchers"
  gem "capybara"        # system specs
  gem "selenium-webdriver"
  gem "pdf-reader"      # assert PDF text content in spec/pdf/
end

group :development do
  gem "rubocop-rails-omakase", require: false
  gem "web-console"
end
```

---

## Rails Application Structure

```
app/
├── actors/
│   ├── actors/
│   │   ├── apply_workshop_substitution.rb
│   │   ├── update_registration_override.rb
│   │   ├── update_staff_field.rb
│   │   ├── add_staff_advance.rb
│   │   ├── remove_staff_advance.rb
│   │   ├── add_staff_payment.rb
│   │   ├── remove_staff_payment.rb
│   │   ├── trigger_helloasso_sync.rb
│   │   └── update_edition_settings.rb
├── controllers/
│   ├── application_controller.rb       # authenticate_user!, current_edition helper
│   ├── dashboard_controller.rb
│   ├── editions_controller.rb
│   ├── participants_controller.rb
│   ├── workshops_controller.rb
│   ├── registrations_controller.rb
│   ├── orders_controller.rb
│   ├── staff_profiles_controller.rb
│   ├── staff_advances_controller.rb
│   ├── staff_payments_controller.rb
│   ├── workshop_substitutions_controller.rb
│   ├── exports_controller.rb
│   └── webhooks/
│       └── helloasso_controller.rb
├── models/
│   ├── edition.rb
│   ├── workshop.rb
│   ├── person.rb
│   ├── order.rb
│   ├── registration.rb
│   ├── registration_workshop.rb
│   ├── staff_profile.rb
│   ├── staff_advance.rb
│   └── staff_payment.rb
├── services/
│   ├── helloasso/
│   │   ├── client.rb                   # Faraday connection, token management
│   │   ├── sync_service.rb             # orchestrates a full edition sync
│   │   └── webhook_processor.rb        # processes incoming webhook payloads
│   └── importers/
│       ├── participants_csv_importer.rb # Sheet 1 CSV → people/registrations/workshops
│       └── staff_csv_importer.rb       # Sheet 2 CSV → staff_profiles
├── jobs/
│   ├── helloasso_sync_job.rb           # Sidekiq job wrapping sync_service
│   └── application_job.rb
├── pdf/
│   ├── fiche_indemnisation_pdf.rb      # Prawn document for staff indemnisation
│   └── workshop_roster_pdf.rb          # Prawn document for workshop rosters
├── views/
│   └── (standard Rails views, ERB)
└── helpers/
    └── application_helper.rb           # format_euros, format_date, etc.

config/
├── sidekiq.yml
├── initializers/
│   ├── sidekiq.rb
│   ├── pagy.rb
│   └── paper_trail.rb
└── schedule.rb                         # sidekiq-cron schedule

lib/
└── tasks/
    ├── import_participants.rake
    └── import_staff.rake
```

---

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://psalmo:psalmo@localhost:5432/psalmo_manager_development

# Redis
REDIS_URL=redis://localhost:6379/0

# HelloAsso
HELLOASSO_CLIENT_ID=your_client_id
HELLOASSO_CLIENT_SECRET=your_client_secret
HELLOASSO_ORG_SLUG=psalmodia          # the organisation slug on HelloAsso
HELLOASSO_WEBHOOK_SECRET=your_secret  # for webhook signature verification

# Rails
RAILS_MASTER_KEY=...                  # for credentials
SECRET_KEY_BASE=...                   # production only
```

---

## Key Configuration Decisions

### Why Importmap (not esbuild/Vite)?
Hotwire + Stimulus + Chartkick + Tailwind cover all frontend needs. No npm build pipeline is
required, which drastically simplifies deployment and removes Node.js as a dependency.

### Why Faraday (not HTTParty)?
Faraday's middleware stack makes it straightforward to add retry logic, logging, and the custom
OAuth2 token-refresh middleware without monkey-patching. The `faraday-retry` gem handles
transient errors automatically.

### Why Prawn (not WickedPDF/PDFKit)?
WickedPDF and PDFKit require a headless browser (wkhtmltopdf) which is painful to install on
servers. Prawn is a pure-Ruby PDF library with no system dependencies. The indemnisation form
has a well-defined structure that maps naturally to Prawn's box/table primitives.

### Why Pagy (not Kaminari)?
Pagy is ~40x faster than Kaminari for large datasets and has zero dependencies. The API is
slightly different but the migration cost is negligible.

### Why no Ransack?
The filtering needs are simple enough to handle with hand-written scopes on models. Ransack
adds complexity (and potential security surface) that isn't warranted here.

---

## Auto-Save Pattern (Stimulus `autosave` Controller)

Several pages use **per-field auto-save on blur** instead of a traditional form submit button:
- Staff profile edit fields (`allowance_cents`, `km_traveled`, `transport_mode`, etc.)
- Registration override fields (`excluded_from_stats`, `is_unaccompanied_minor`,
  `responsible_person_note`) — both inline in the participant list and on the show page
- Edition settings fields (`km_rate_cents`, `name`, etc.)

### How it works

1. Each auto-save field is wrapped in a Stimulus `autosave` controller target.
2. On `blur` (or `change` for checkboxes/selects), the controller fires a `fetch` PATCH request
   to the field's URL with the single field name + value.
3. The controller URL convention is `/<resource>/:id` with a `_field` suffix on the param name
   to distinguish from a full-form save.
4. The server responds with a **Turbo Stream** that:
   - On success: replaces `<div id="field_error_<field_name>">` with empty content, and briefly
     shows a "Sauvegardé ✓" indicator.
   - On failure: replaces `<div id="field_error_<field_name>">` with the error message.

### Stimulus controller skeleton

```javascript
// app/javascript/controllers/autosave_controller.js
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
      headers: { "Accept": "text/vnd.turbo-stream.html",
                 "X-CSRF-Token": document.querySelector("[name='csrf-token']").content },
      body
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
  }
}
```

### HTML usage example

```erb
<%# app/views/staff_profiles/_field.html.erb %>
<div data-controller="autosave"
     data-autosave-url-value="<%= staff_profile_path(@staff_profile) %>"
     data-autosave-param-value="staff_profile[allowance_cents]">
  <%= f.text_field :allowance_cents,
        data: { autosave_target: "field", action: "blur->autosave#save" } %>
  <div id="field_error_allowance_cents" class="text-red-600 text-sm"></div>
</div>
```

### Server-side response (Turbo Stream)

```ruby
# app/controllers/staff_profiles_controller.rb
def update
  result = Actors::UpdateStaffField.call(
    staff_profile: @staff_profile,
    field: params[:field],
    value: params.dig(:staff_profile, params[:field].to_sym)
  )
  if result.success?
    render turbo_stream: [
      turbo_stream.update("field_error_#{params[:field]}", ""),
      turbo_stream.update("financial_summary", partial: "financial_summary",
                          locals: { staff_profile: @staff_profile })
    ]
  else
    render turbo_stream:
      turbo_stream.update("field_error_#{params[:field]}",
                          html: %(<span class="text-red-600 text-sm">#{result.error}</span>))
  end
end
```

### Pages using auto-save

| Page | Fields |
|---|---|
| Staff profile show/edit | All financial fields, transport, km, notes |
| Registration show + inline in participant list | `excluded_from_stats`, `is_unaccompanied_minor`, `responsible_person_note` |
| Edition settings (`editions#edit`) | `km_rate_cents`, `name`, `start_date`, `end_date` |
