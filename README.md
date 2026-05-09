# psalmo-manager

Rails administration application for **Psalmodia**, an annual artistic summer camp held in
Gagnières, France. Replaces a collection of Google Sheets used to manage participants,
workshops, staff finances, and PDF indemnisation forms.

## What it does

- **Syncs registrations** from HelloAsso automatically (every 30 min via Sidekiq + webhook)
- **Participant management**: search, filter by edition/age/workshop, handle manual overrides
  (workshop substitutions, stat exclusions, unaccompanied minors)
- **Workshop management**: capacity tracking, fill rates, time-slot assignment, per-atelier rosters
- **Staff finances**: travel allowances, advances, disbursements, automatic balance computation
- **PDF generation**: workshop rosters and the "Fiche d'indemnisation animateur" per staff member
- **Dashboards**: revenue, fill rates, age distribution, weekly registration cadence
- **CSV exports**: filtered participant, workshop, staff, and financial lists
- **Multi-edition**: all views are scoped to an edition; historical editions remain accessible

Admin-only. No public portal. Devise protects all routes.

## Tech stack

| | |
|---|---|
| Ruby | 3.3.11 |
| Rails | 7.2 |
| Database | PostgreSQL 16 |
| Background jobs | Sidekiq 7 + sidekiq-cron |
| Cache / queue | Redis 7 |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS, Importmap |
| Authentication | Devise |
| PDF | Prawn + prawn-table |
| Charts | Chartkick + Groupdate |
| HTTP client | Faraday + faraday-retry |
| Actor pattern | Interactor |
| Audit log | PaperTrail |

## Development setup

### Prerequisites

- Docker and Docker Compose

### 1. Clone and configure

```sh
git clone <repo-url> psalmo-manager
cd psalmo-manager
cp .env.example .env
```

Edit `.env` and fill in the HelloAsso credentials:

```sh
HELLOASSO_CLIENT_ID=your_client_id
HELLOASSO_CLIENT_SECRET=your_client_secret
HELLOASSO_ORG_SLUG=psalmodia
HELLOASSO_WEBHOOK_SECRET=your_webhook_secret
```

The database and Redis URLs are pre-configured for the Docker Compose network.

### 2. Start services

```sh
docker compose up
```

This starts `postgres`, `redis`, `app` (Rails on port 3000), `sidekiq`, and `selenium`
(for JS system specs, port 4444).

### 3. Set up the database

```sh
docker compose exec app bundle exec rails db:create db:migrate db:seed
```

`db:seed` creates the first admin user:

```
email:    admin@psalmodia.fr
password: psalmodia2026!
```

### 4. Open the app

Visit [http://localhost:3000](http://localhost:3000) and sign in with the seeded credentials.

## Running tests

Always pass `-e RAILS_ENV=test` — the container default is `development`:

```sh
docker compose exec -e RAILS_ENV=test app bundle exec rspec
```

Run a specific file or folder:

```sh
docker compose exec -e RAILS_ENV=test app bundle exec rspec spec/system/
docker compose exec -e RAILS_ENV=test app bundle exec rspec spec/requests/exports_spec.rb
```

Current suite: **295 examples, 0 failures**.

### Test drivers

System specs use `rack_test` by default (no browser required). Tag individual examples with
`js: true` to use the remote Selenium Chrome container instead:

```ruby
it "does something with JavaScript", js: true do
  # uses selenium_remote_chrome
end
```

## Linting

```sh
docker compose exec app bundle exec rubocop
```

## Data import (one-time migration from Google Sheets)

Two rake tasks import historical data from CSV exports:

```sh
# Import participants (Sheet 1 — registrations, workshops, overrides)
docker compose exec app bundle exec rake import:participants \
  CSV=path/to/donnes_brutes.csv \
  FILTRES=path/to/filtres.csv \
  EXCLUSIONS=path/to/exclusions.csv \
  MINEURS=path/to/mineurs.csv \
  EDITION_ID=1

# Import staff profiles and payments (Sheet 2)
docker compose exec app bundle exec rake import:staff \
  RECAP=path/to/staff_recap.csv \
  VERSEMENTS=path/to/versements.csv \
  EDITION_ID=1
```

Both tasks are idempotent — running them twice will not create duplicates.

## Architecture notes

### Actor pattern

Every write action goes through an actor in `app/actors/actors/`. Controllers call one actor,
check `context.success?`, and redirect or surface an inline error. Controllers never call
`.create` or `.update` directly on models.

### Current edition

`current_edition` in `ApplicationController` resolves from `session[:edition_id]`, falling back
to the most recent edition by year. Switch editions via the sidebar selector.

### Money

All monetary values are stored as **integer euro cents** (e.g. `5000` = 50,00 €). Never floats.
The `format_euros` helper handles display formatting.

### Auto-save

Financial fields on staff profiles and override fields on registrations use per-field PATCH on
blur via a Stimulus `autosave` controller. Errors appear inline next to the field — no flash
banner.

### Turbo Stream + HTML fallback

Controllers that render `turbo_stream` responses (advances, payments) also include an
`format.html { redirect_to ... }` fallback so that plain-HTML clients and `rack_test`-based specs
work correctly.

## Project planning

All design documents live in `.plan/`. Start with `.plan/AGENTS.md` for a navigation guide.

| File | Contents |
|---|---|
| `01-project-overview.md` | Goals, non-goals, glossary, constraints |
| `02-technical-stack.md` | Gems, infrastructure, actor pattern, auto-save, Turbo conventions |
| `03-data-model.md` | All tables, columns, enums, associations |
| `04-helloasso-integration.md` | API v5, OAuth2, sync strategy, override-preservation |
| `05-data-sources.md` | Google Sheets structure, CSV import strategy |
| `06-ui-ux.md` | Page inventory, controller map, Turbo Frame patterns |
| `07-pdf-fiche-indemnisation.md` | PDF layout spec, Prawn implementation |
| `08-development-phases.md` | 8-phase delivery plan (all phases complete) |
| `09-testing-strategy.md` | RSpec structure, factories, system spec rules |
| `10-business-rules.md` | Pricing, age categories, km rates, balance formulas |
| `11-actors.md` | Full actor catalogue with inputs, outputs, and guards |
