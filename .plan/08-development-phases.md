# 08 — Development Phases

## Overview

The project is divided into 8 sequential phases. Each phase has a clear goal, a list of tasks,
the files to create or modify, and acceptance criteria (definition of done).

Phases must be completed in order — each phase's acceptance criteria must be met before the next
phase begins, because later phases depend on the infrastructure established earlier.

---

## Phase 1 — Project Setup

**Goal**: A working Rails application skeleton with all infrastructure in place. No business logic
yet, but everything needed to develop is ready.

### Tasks

1. Run `rails new psalmo-manager --database=postgresql --css=tailwind --javascript=importmap`
2. Create `docker-compose.yml` with `postgres:16` and `redis:7-alpine` services
3. Add all gems to `Gemfile` (see `.plan/02-technical-stack.md` for the full list)
4. Run `bundle install`
5. Configure Devise: `rails generate devise:install`, create `User` model, `rails generate devise User`
6. Remove Devise self-registration: disable registrations route, add seed for first admin
7. Configure Sidekiq: `config/initializers/sidekiq.rb`, `config/sidekiq.yml`
8. Mount Sidekiq Web UI at `/sidekiq` (protected by Devise)
9. Install RSpec: `rails generate rspec:install`
10. Configure FactoryBot, Shoulda Matchers, WebMock in `spec/rails_helper.rb`
11. Install PaperTrail: `rails generate paper_trail:install` → creates `versions` migration
12. Create `config/initializers/paper_trail.rb` with `track_associations: false`
13. Add `user_for_paper_trail` and `set_paper_trail_whodunnit` to `ApplicationController`
14. Create base application layout with Tailwind sidebar (see `.plan/06-ui-ux.md`)
15. Create `ApplicationController` with `before_action :authenticate_user!` and
    `current_edition` helper
16. Create `SessionsController#update_edition` for the edition switcher
17. Configure `config/database.yml` to use `DATABASE_URL` env var
18. Create `.env.example` with all required env vars (no values)
19. Configure RuboCop with `rubocop-rails-omakase`
20. Create `db/seeds.rb` with first admin user

### Files to create

```
docker-compose.yml
.env.example
.rubocop.yml
config/sidekiq.yml
config/initializers/sidekiq.rb
config/initializers/pagy.rb
config/initializers/paper_trail.rb
app/controllers/application_controller.rb (modify)
app/controllers/sessions_controller.rb
app/views/layouts/application.html.erb (modify)
app/views/layouts/_sidebar.html.erb
app/views/layouts/_flash.html.erb
app/javascript/controllers/flash_controller.js
app/javascript/controllers/edition_switcher_controller.js
db/seeds.rb
spec/rails_helper.rb (modify)
spec/spec_helper.rb (modify)
spec/support/factory_bot.rb
spec/support/shoulda_matchers.rb
```

### Acceptance Criteria

- [ ] `docker compose up` starts postgres and redis without errors
- [ ] `rails db:create db:migrate` succeeds
- [ ] `rails server` starts and `/users/sign_in` loads
- [ ] After signing in with the seeded admin, the sidebar layout renders
- [ ] `bundle exec rspec` runs with 0 failures (only pending specs at this point)
- [ ] `bundle exec rubocop` passes with no offences

---

## Phase 2 — Migrations & Models

**Goal**: All database tables exist, all ActiveRecord models are defined with associations,
validations, enums, and basic scopes. FactoryBot factories exist for all models.

### Tasks

1. Generate migrations in dependency order (see `.plan/03-data-model.md`; `versions` table first
   via `rails generate paper_trail:install` — already done in Phase 1)
2. Run all migrations
3. Create all model files with associations, validations, enums (`enfant`/`adulte`), and
   `has_paper_trail`
4. Create all FactoryBot factories in `spec/factories/`
5. Write model unit tests (validations, associations, computed methods)
6. Create `ApplicationHelper#format_euros` and `#format_date`

### Files to create

```
db/migrate/YYYYMMDD_create_editions.rb
db/migrate/YYYYMMDD_create_workshops.rb
db/migrate/YYYYMMDD_create_people.rb
db/migrate/YYYYMMDD_create_orders.rb
db/migrate/YYYYMMDD_create_registrations.rb
db/migrate/YYYYMMDD_create_registration_workshops.rb
db/migrate/YYYYMMDD_create_staff_profiles.rb
db/migrate/YYYYMMDD_create_staff_advances.rb
db/migrate/YYYYMMDD_create_staff_payments.rb
app/models/edition.rb
app/models/workshop.rb
app/models/person.rb
app/models/order.rb
app/models/registration.rb
app/models/registration_workshop.rb
app/models/staff_profile.rb
app/models/staff_advance.rb
app/models/staff_payment.rb
app/helpers/application_helper.rb
spec/factories/editions.rb
spec/factories/workshops.rb
spec/factories/people.rb
spec/factories/orders.rb
spec/factories/registrations.rb
spec/factories/registration_workshops.rb
spec/factories/staff_profiles.rb
spec/factories/staff_advances.rb
spec/factories/staff_payments.rb
spec/models/edition_spec.rb
spec/models/workshop_spec.rb
spec/models/person_spec.rb
spec/models/registration_spec.rb
spec/models/staff_profile_spec.rb
```

### Acceptance Criteria

- [ ] `rails db:migrate` succeeds with no errors
- [ ] `rails db:schema:load` works from a clean state
- [ ] All models load without errors (`rails runner "puts Edition.count"`)
- [ ] `bundle exec rspec spec/models` passes with coverage for all validations and computed fields
- [ ] FactoryBot factories build valid records (`FactoryBot.lint` passes)

---

## Phase 3 — HelloAsso API Client & Sync

**Goal**: The application can authenticate with HelloAsso and sync a full edition's orders and
registrations. The webhook endpoint is functional.

### Tasks

1. Create `app/services/helloasso/client.rb` with Faraday connection and OAuth2 token management
2. Create `app/services/helloasso/sync_service.rb` (respecting override-preservation contract —
   see `.plan/04-helloasso-integration.md#override-preservation-contract`)
3. Create `app/jobs/helloasso_sync_job.rb`
4. Create `app/actors/actors/trigger_helloasso_sync.rb` (actor wrapping the sync job enqueue)
5. Create `config/schedule.rb` with sidekiq-cron configuration
6. Create `app/controllers/webhooks/helloasso_controller.rb`
7. Create `app/services/helloasso/webhook_processor.rb`
8. Add webhook route to `config/routes.rb`
9. Write unit tests for the client (WebMock stubs)
10. Write unit tests for the sync service (WebMock stubs); verify override fields are preserved
11. Write request spec for the webhook endpoint

### Files to create

```
app/services/helloasso/client.rb
app/services/helloasso/sync_service.rb
app/services/helloasso/webhook_processor.rb
app/jobs/helloasso_sync_job.rb
app/actors/actors/trigger_helloasso_sync.rb
app/controllers/webhooks/helloasso_controller.rb
config/schedule.rb
spec/services/helloasso/client_spec.rb
spec/services/helloasso/sync_service_spec.rb
spec/requests/webhooks/helloasso_spec.rb
spec/fixtures/vcr_cassettes/helloasso/ (directory)
spec/fixtures/helloasso/ (sample JSON payloads)
```

### Acceptance Criteria

- [ ] `HelloassoSyncJob.perform_now(edition.id)` runs without error (with WebMock stubs)
- [ ] After sync, `Order.count` and `Registration.count` reflect the stubbed API data
- [ ] Re-running sync does not overwrite `excluded_from_stats`, `is_unaccompanied_minor`,
  `responsible_person_note`, or `registration_workshops` with `is_override: true`
- [ ] `POST /webhooks/helloasso` with valid signature returns 200
- [ ] `POST /webhooks/helloasso` with invalid signature returns 401
- [ ] `bundle exec rspec spec/services/helloasso spec/requests/webhooks` passes

---

## Phase 4 — CSV Importer: Participants

**Goal**: A rake task can import a Sheet 1 CSV export into the database, handling the workshop
column pivot, payer/participant merge, overrides, stat exclusions, and unaccompanied minors.

### Tasks

1. Create `app/services/importers/participants_csv_importer.rb`
2. Create `lib/tasks/import_participants.rake`
3. Handle workshop column detection and pivot logic
4. Handle payer vs participant merge
5. Apply overrides (from a separate `filtres.csv` input)
6. Apply stat exclusions (from a separate `exclusions.csv` input)
7. Apply unaccompanied minor flags (from a separate `mineurs.csv` input)
8. Write unit tests with fixture CSV files

### Files to create

```
app/services/importers/participants_csv_importer.rb
app/services/importers/filtres_csv_importer.rb
app/services/importers/exclusions_csv_importer.rb
app/services/importers/mineurs_csv_importer.rb
lib/tasks/import_participants.rake
spec/services/importers/participants_csv_importer_spec.rb
spec/fixtures/csv/donnes_brutes_sample.csv
spec/fixtures/csv/filtres_sample.csv
spec/fixtures/csv/exclusions_sample.csv
spec/fixtures/csv/mineurs_sample.csv
```

### Acceptance Criteria

- [ ] Running the rake task on a sample CSV creates the expected records
- [ ] Idempotent: running the rake task twice does not create duplicates
- [ ] Workshop columns are correctly identified and pivoted
- [ ] Payer ≠ participant is correctly handled (two `Person` records, one `Order`)
- [ ] `bundle exec rspec spec/services/importers` passes

---

## Phase 5 — CSV Importer: Staff

**Goal**: A rake task can import Sheet 2 CSV exports into `staff_profiles`, `staff_advances`,
and `staff_payments`.

### Tasks

1. Create `app/services/importers/staff_csv_importer.rb`
2. Create `lib/tasks/import_staff.rake`
3. Parse `Recapitulatif Frais Animateur` tab → `StaffProfile`
4. Parse `Versements` tab → `StaffAdvance` / `StaffPayment`
5. Match staff rows to existing `Person` records by name (or create new ones)
6. Write unit tests with fixture CSV files

### Files to create

```
app/services/importers/staff_csv_importer.rb
app/services/importers/versements_csv_importer.rb
lib/tasks/import_staff.rake
spec/services/importers/staff_csv_importer_spec.rb
spec/fixtures/csv/staff_recap_sample.csv
spec/fixtures/csv/versements_sample.csv
```

### Acceptance Criteria

- [ ] Running the rake task on sample CSVs creates expected `StaffProfile`, `StaffAdvance`,
  `StaffPayment` records
- [ ] Idempotent: running twice does not create duplicates
- [ ] Computed fields (`dossier_number`, `balance_cents`) are correct
- [ ] `bundle exec rspec spec/services/importers/staff` passes

---

## Phase 6 — UI (Hotwire / Turbo)

**Goal**: All admin pages are functional: CRUD for editions and workshops, read views for
participants and orders, staff profile editor with inline advances/payments, workshop substitution
page.

### Tasks

1. Dashboard controller and view (static numbers, charts wired up)
2. Editions CRUD — controllers call `Actors::UpdateEditionSettings`
3. Workshops CRUD + roster view
4. Participants index (with filters) + show page with inline override fields (auto-save)
5. Orders index + show page
6. Staff profiles CRUD + show page with financial summary (auto-save on all financial fields)
7. Staff advances inline add/remove (Turbo Frames) — controllers call `Actors::AddStaffAdvance` /
   `Actors::RemoveStaffAdvance`
8. Staff payments inline add/remove (Turbo Frames) — `Actors::AddStaffPayment` /
   `Actors::RemoveStaffPayment`
9. Workshop substitution flow — controller calls `Actors::ApplyWorkshopSubstitution`
10. Edition switcher in sidebar
11. All Stimulus controllers: `flash`, `filter-form`, `confirm-delete`, `currency-input`,
    **`autosave`** (see `.plan/02-technical-stack.md#auto-save-pattern`)
12. Pagy pagination on all index pages
13. Write system specs for critical flows

### Files to create (additions beyond the controller/view files)

```
app/actors/actors/apply_workshop_substitution.rb
app/actors/actors/update_registration_override.rb
app/actors/actors/update_staff_field.rb
app/actors/actors/update_edition_settings.rb
app/actors/actors/add_staff_advance.rb
app/actors/actors/remove_staff_advance.rb
app/actors/actors/add_staff_payment.rb
app/actors/actors/remove_staff_payment.rb
app/javascript/controllers/autosave_controller.js
```

### Acceptance Criteria

- [ ] All index pages load and are paginated
- [ ] All filter forms work
- [ ] Workshop substitution correctly creates an `is_override: true` record (via actor)
- [ ] Adding an advance on the staff profile page updates the financial summary without
  full-page reload (Turbo Frame)
- [ ] Auto-save on a staff profile field sends PATCH, shows "Sauvegardé ✓", and clears on success
- [ ] Auto-save error shows inline message near the field (not flash banner)
- [ ] Registration override fields auto-save inline in participant list and show page
- [ ] Edition switcher persists the selected edition in the session
- [ ] `bundle exec rspec spec/system` passes for: login, participant list, workshop substitution,
  staff advance add

---

## Phase 7 — Dashboards

**Goal**: The dashboard page shows live, edition-scoped stats with charts.

### Tasks

1. Revenue summary card (total billetterie, total ateliers, total general)
2. Workshop fill rate table (with capacity bar rendered in Tailwind)
3. Age distribution bar chart (Chartkick, data from `registrations.for_stats`)
4. Weekly registration cadence line chart (Chartkick + Groupdate)
5. Unaccompanied minors count + quick link
6. Last 5 registrations widget
7. All queries must respect `excluded_from_stats` flag
8. Write unit tests for the query methods used in the dashboard

### Files to create

```
app/controllers/dashboard_controller.rb
app/views/dashboard/index.html.erb
app/queries/dashboard_stats.rb  (query object extracting all DB queries)
spec/queries/dashboard_stats_spec.rb
```

### Acceptance Criteria

- [ ] Dashboard loads in < 1 second with 300 registrations and 35 workshops in test DB
- [ ] Switching editions updates all stats correctly
- [ ] Excluded registrations are not counted in revenue or participant totals
- [ ] Charts render with correct data
- [ ] `bundle exec rspec spec/queries` passes

---

## Phase 8 — Exports & PDFs

**Goal**: All CSV exports work. Workshop roster PDFs work. The "Fiche d'indemnisation animateur"
PDF is correct for all edge cases.

### Tasks

1. Participant list CSV export (filtered)
2. Workshop roster CSV export
3. Contacts CSV export (Tableau CCG equivalent)
4. Unaccompanied minors CSV export
5. Workshop roster PDF (Prawn — name, age category, phone, email per participant)
6. `FicheIndemnisationPdf` Prawn class (see `.plan/07-pdf-fiche-indemnisation.md`)
7. Wire up the "Générer la fiche PDF" button on staff profile show page
8. Write unit tests for all PDF classes (check content presence, not pixel layout)

### Files to create

```
app/controllers/exports_controller.rb
app/views/exports/index.html.erb
app/pdf/fiche_indemnisation_pdf.rb
app/pdf/workshop_roster_pdf.rb
spec/pdf/fiche_indemnisation_pdf_spec.rb
spec/pdf/workshop_roster_pdf_spec.rb
```

### Acceptance Criteria

- [ ] Participant CSV downloads with correct headers and UTF-8 BOM
- [ ] Workshop roster PDF contains correct participant names
- [ ] Fiche PDF renders correctly for: normal case, zero advances, instructor owes, Psalmodia owes,
  balance = 0
- [ ] Fiche PDF filename includes dossier number and last name
- [ ] `bundle exec rspec spec/pdf` passes
- [ ] `bundle exec rspec` (full suite) passes

---

## Ongoing / Cross-cutting

- **RuboCop** must pass at the end of each phase: `bundle exec rubocop`
- **Full test suite** must pass at the end of each phase: `bundle exec rspec`
- **No N+1 queries**: use `includes` / `preload` on all index and show pages. Use
  `Bullet` gem in development if N+1 queries appear.
- **No hardcoded edition**: every query is scoped via `current_edition` from the session.
