# 01 — Project Overview

## Background

**Psalmodia** is an annual artistic summer camp held in Gagnières, France, organised by a French
non-profit association. Each edition runs for approximately one week and brings together ~250
participants (children, teenagers, adults) who attend workshops in circus, theatre, music, crafts,
and other arts.

Registrations are handled through **HelloAsso**, a French payment platform for non-profits. The
association currently manages all post-registration operations — participant lists, workshop
rosters, financial tracking, staff indemnisation — using a collection of **Google Sheets** that
are manually maintained and error-prone.

**psalmo-manager** replaces those Google Sheets with a purpose-built Rails administration
application.

---

## Problem Statement

The current Google Sheets setup has the following pain points:

- Workshop rosters must be built manually by copy-pasting HelloAsso export data
- Workshop substitutions (changing a participant's atelier) require editing multiple sheets
- Staff financial tracking (travel allowances, advances, disbursements) lives in a separate
  spreadsheet with no connection to participant data
- The "Fiche d'indemnisation animateur" PDF must be assembled by hand from the spreadsheet
- Statistics (fill rates, revenue, age distribution) require manual formula maintenance
- There is no audit trail for manual overrides
- Multi-year comparisons are not possible

---

## Goals

1. **Import** registration data from HelloAsso automatically (sync every 30 min + real-time
   webhooks) and via one-time CSV migration from existing Google Sheets data.
2. **Manage participants**: view, search, filter by edition/age/workshop/status; handle manual
   overrides (workshop substitutions, stat exclusions, unaccompanied minors).
3. **Manage workshops**: capacity tracking, fill rate, time slot assignment, per-atelier rosters.
4. **Manage staff**: financial profiles for instructors and organisers; track advances and
   disbursements; compute balances automatically.
5. **Generate PDFs**: workshop rosters and the "Fiche d'indemnisation animateur" for each staff
   member.
6. **Dashboards**: revenue, workshop fill rates, age distribution, weekly registration cadence.
7. **Exports**: filtered CSV lists for any roster view.
8. **Multi-year**: support multiple editions from day one; all queries are scoped to an edition.

---

## Non-Goals

The following are explicitly out of scope:

- No public-facing portal (no parent login, no self-service registration)
- No replacement of HelloAsso as the payment processor
- No email sending to participants or parents (HelloAsso handles that)
- No mobile app
- No real-time chat or notifications to parents
- No financial accounting beyond staff indemnisation (no general ledger)

---

## Users

There is exactly **one type of user**: administrators of the Psalmodia association.

- Authentication is handled by Devise (email + password).
- There is no self-registration — admin accounts are created by seeding or via `rails console`.
- There is no role hierarchy for now (all admins have full access).

---

## Edition Model

Each year's camp is one **Edition**. The application supports multiple editions.

- All participants, registrations, workshops, and staff profiles belong to an edition.
- Dashboards and list views default to the current (most recent) edition but can be switched.
- Historical editions are read-only in practice (no new HelloAsso data will arrive for them)
  but remain fully accessible.

---

## Data Sources

Two external data sources feed the application:

1. **HelloAsso API v5** — live registration data (ongoing sync)
2. **Google Sheets CSVs** — historical data for the 2025/2026 editions (one-time import)

See `.plan/04-helloasso-integration.md` and `.plan/05-data-sources.md` for details.

---

## Glossary

| Term | Definition |
|---|---|
| **Edition** | One year's camp (e.g. "Psalmodia 2026") |
| **Participant** | A person who registered for the camp (via HelloAsso or manually) |
| **Animateur / Instructeur** | A workshop instructor (staff member who leads an atelier) |
| **Organisateur / Staff** | A non-instructor staff member (organiser, volunteer) |
| **Atelier** | A workshop session (e.g. "CIRQUE", "THÉATRE ENFANTS") |
| **Créneau** | Time slot: `matin` (morning), `apres_midi` (afternoon), `journee` (full day) |
| **Inscription** | A registration record linking a person to an edition |
| **Billet** | A HelloAsso ticket — one per participant per edition |
| **Commande** | A HelloAsso order — one per paying family/group |
| **Payeur** | The person who placed the HelloAsso order (usually same as participant) |
| **Mineur seul** | An unaccompanied minor — attends without a parent/guardian |
| **Fiche d'indemnisation** | The staff reimbursement form generated as a PDF |
| **Acompte** | An advance payment made by the instructor to Psalmodia |
| **Versement** | A disbursement made by Psalmodia to the instructor |
| **Dossier** | A staff member's indemnisation record (identified by `dossier_number`) |

---

## Constraints

- **French law**: The association is a French "loi 1901" non-profit. Travel reimbursement rates
  follow French fiscal guidelines (configurable per edition).
- **HelloAsso**: The API is rate-limited. Webhooks require a publicly accessible endpoint.
- **Data privacy**: Participant personal data (name, DOB, email, phone) must be handled with care.
  The application is not exposed to the public internet beyond the webhook endpoint.
- **Single server**: The application runs on a single server (no Kubernetes, no microservices).
  Sidekiq runs on the same machine as the Rails app.
