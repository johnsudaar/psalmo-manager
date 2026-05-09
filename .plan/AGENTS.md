# AGENTS.md — Navigation Guide for AI Agents

This file is the entry point for any agent (planning, implementation, review, testing) working on
the **psalmo-manager** project. Read this first, then follow the pointers to the relevant documents.

---

## What is this project?

A Ruby on Rails admin application that replaces a collection of Google Sheets used to manage
**Psalmodia**, a French artistic summer camp. It imports registration data from HelloAsso, manages
participants, workshops, staff finances, and generates PDF indemnisation forms.

See `.plan/01-project-overview.md` for the full context.

---

## Document Map

| File | What it covers |
|---|---|
| `01-project-overview.md` | Goals, users, constraints, non-goals, glossary |
| `02-technical-stack.md` | Gems, versions, infrastructure, config decisions, auto-save pattern |
| `03-data-model.md` | All DB tables, columns, enums, associations, ER diagram |
| `04-helloasso-integration.md` | API v5, OAuth2, sync strategy, override-preservation, webhooks |
| `05-data-sources.md` | Both Google Sheets dissected, CSV import strategy |
| `06-ui-ux.md` | Page inventory, controllers, Turbo Frames, Stimulus, auto-save, nav |
| `07-pdf-fiche-indemnisation.md` | PDF layout spec, formulas, Prawn implementation guide |
| `08-development-phases.md` | 8-phase plan, task lists, acceptance criteria |
| `09-testing-strategy.md` | RSpec structure, factories, what/how to test |
| `10-business-rules.md` | Domain logic: pricing, age categories, km rates, formulas |
| `11-actors.md` | Full actor catalogue: inputs, outputs, guards, test expectations |

---

## Role-Based Reading Guide

### "I am implementing actors and controllers"
1. `11-actors.md` — full catalogue, inputs, outputs, guards
2. `02-technical-stack.md` — actor pattern section and auto-save pattern
3. `06-ui-ux.md` — which pages trigger which actors

### "I am setting up the project from scratch"
1. `01-project-overview.md` — understand what you're building
2. `02-technical-stack.md` — exact gems, versions, Docker setup
3. `08-development-phases.md` — Phase 1 task list

### "I am writing migrations and models"
1. `03-data-model.md` — source of truth for every table and column
2. `10-business-rules.md` — enums, constraints, calculated fields
3. `09-testing-strategy.md` — factory definitions to write alongside models

### "I am implementing the HelloAsso sync"
1. `04-helloasso-integration.md` — full API reference, token flow, webhook
2. `03-data-model.md` — which fields map to which API response fields
3. `02-technical-stack.md` — Faraday, Sidekiq-cron setup

### "I am building the CSV importer (Google Sheets migration)"
1. `05-data-sources.md` — sheet structure, column mapping, pivot logic
2. `03-data-model.md` — target tables and columns
3. `10-business-rules.md` — age category inference, workshop slot rules

### "I am building UI pages"
1. `06-ui-ux.md` — full page inventory, controller/action map, Turbo Frame patterns
2. `10-business-rules.md` — what the UI must enforce or display
3. `03-data-model.md` — what data is available per page

### "I am generating the indemnisation PDF"
1. `07-pdf-fiche-indemnisation.md` — section-by-section layout spec, formulas, edge cases
2. `03-data-model.md` — `staff_profiles`, `staff_advances`, `staff_payments` tables
3. `10-business-rules.md` — balance calculation rules

### "I am writing tests"
1. `09-testing-strategy.md` — folder structure, factory list, coverage expectations
2. `11-actors.md` — actor specs: inputs, expected outputs, failure paths
3. `03-data-model.md` — models to cover
4. `10-business-rules.md` — business rules that need unit tests

### "I am reviewing a pull request"
1. `01-project-overview.md` — does this PR align with project goals?
2. `08-development-phases.md` — is this in scope for the current phase?
3. `10-business-rules.md` — are domain rules correctly implemented?
4. `09-testing-strategy.md` — is test coverage adequate?

### "I am planning the next iteration / sprint"
1. `08-development-phases.md` — current phase status, next phase prerequisites
2. `01-project-overview.md` — non-goals to avoid scope creep

---

## Key Conventions (all agents must respect)

- **Language**: The application UI is in **French**. All labels, flash messages, model error
  messages, and PDF text are in French. Code (variable names, method names, comments) is in
  **English**.
- **Money**: All monetary amounts are stored as **integers in euro cents** (e.g. `5000` = 50,00 €).
  Never store floats for money. Use the `amount_cents` suffix convention.
- **Dates**: Stored as `date` (no time component) unless a timestamp is genuinely needed.
- **Enums**: Defined on the model using Rails `enum`, always with explicit integer mapping so
  database values never shift if the list is reordered.
- **No public portal**: This is an admin-only application. There is no registration, no parent
  portal, no public-facing page. Devise protects all routes.
- **Multi-edition**: Every aggregate query must be scoped to an `edition`. Never query across
  all editions without an explicit intent.
- **KISS**: Do not add complexity that has not been explicitly asked for. No extra columns,
  validations, abstractions, or features beyond what is specified. When in doubt, do less.
  See `01-project-overview.md#constraints` for the full statement.
- **Actor pattern**: Controllers call one actor per write action. Never call model `.update` or
  `.create` directly from a controller. See `11-actors.md` and `02-technical-stack.md`.
- **Auto-save**: Financial fields on staff profiles, registration override fields, and edition
  settings use per-field PATCH on blur. Inline errors only — no flash banner for auto-save.
  See `02-technical-stack.md#auto-save-pattern`.
- **Override preservation**: HelloAsso-owned fields are overwritten on sync. Override-owned fields
  (`excluded_from_stats`, `is_unaccompanied_minor`, `responsible_person_note`,
  `registration_workshops` with `is_override: true`) are **never** overwritten by sync.
  See `04-helloasso-integration.md#override-preservation-contract`.
- **Audit log**: All models have `has_paper_trail skip: [:updated_at], skip_unchanged: true`.
  `whodunnit` = `current_user.email`. Sync changes are tracked.
- **Test coverage**: All service objects, actors, and models with business logic must have unit
  tests. Happy path + at least one failure path per public method.
- **Test execution**: Run specs from the Docker app container, not from the host. Use
  `docker compose exec -e RAILS_ENV=test app bundle exec rspec ...`.
