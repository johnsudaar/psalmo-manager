# 06 — UI / UX

## Principles

- **French language** everywhere in the UI: labels, buttons, flash messages, error messages.
- **Admin-only**: every route is protected by `before_action :authenticate_user!` in
  `ApplicationController`. No public pages.
- **Edition-scoped**: a persistent "edition switcher" in the sidebar lets admins switch context.
  The current edition is stored in the session (`session[:edition_id]`).
- **Hotwire-first**: prefer Turbo Drive for navigation, Turbo Frames for inline updates (form
  submissions, add/remove rows), Turbo Streams for real-time updates from the sync job.
- **No JavaScript framework**: all interactivity via Stimulus controllers + Turbo. No React/Vue.
- **Tailwind CSS**: utility-first. No custom CSS files unless absolutely necessary.

---

## Layout

### Sidebar navigation

Fixed left sidebar on desktop, collapsible on mobile.

```
┌─────────────────┬──────────────────────────────────┐
│  PSALMO-MANAGER │                                  │
│  [Edition: 2026]│   (main content area)            │
│─────────────────│                                  │
│  Tableau de bord│                                  │
│  ─────────────  │                                  │
│  Participants   │                                  │
│  Commandes      │                                  │
│  Ateliers       │                                  │
│  Changements    │                                  │
│  ─────────────  │                                  │
│  Staff          │                                  │
│  ─────────────  │                                  │
│  Exports        │                                  │
│  ─────────────  │                                  │
│  Paramètres     │                                  │
│  Se déconnecter │                                  │
└─────────────────┴──────────────────────────────────┘
```

### Edition switcher

Displayed below the app name in the sidebar. A `<select>` that submits a form to
`PATCH /session/edition` which updates `session[:edition_id]` and redirects back.

### Flash messages

Styled banner at the top of the content area:
- Green for `:notice`
- Red for `:alert`
- Auto-dismiss after 4 seconds via a Stimulus controller.

---

## Page Inventory & Controller Map

### Dashboard

| Route | Controller#action | Description |
|---|---|---|
| `GET /` | `dashboard#index` | Main dashboard for current edition |

**Content blocks on the dashboard**:
- Revenue summary card: total billetterie, total ateliers, nombre de participants
- Participant counts by age category (enfant / adulte) — two numbers, no chart needed
- Workshop fill rate table: each workshop with capacity bar + %
- Weekly registration cadence line chart (Chartkick + Groupdate)
- Quick links: last 5 registrations, participants flagged as unaccompanied minors,
  registrations with slot conflicts

---

### Editions

| Route | Controller#action | Description |
|---|---|---|
| `GET /editions` | `editions#index` | List all editions |
| `GET /editions/new` | `editions#new` | New edition form |
| `POST /editions` | `editions#create` | Create edition |
| `GET /editions/:id/edit` | `editions#edit` | Edit form |
| `PATCH /editions/:id` | `editions#update` | Update edition |

No deletion (historical data must be preserved).

---

### Participants

| Route | Controller#action | Description |
|---|---|---|
| `GET /participants` | `participants#index` | Paginated list with filters |
| `GET /participants/:id` | `participants#show` | Participant detail page |
| `GET /participants/:id/edit` | `participants#edit` | Edit form |
| `PATCH /participants/:id` | `participants#update` | Update participant |

**Index filters** (form submitted via GET, no JS required):
- Search by name or email (ILIKE)
- Filter by age category (enfant / adulte)
- Filter by workshop (join on registration_workshops)
- Filter by time slot
- Toggle: show only unaccompanied minors
- Toggle: show only registrations with slot conflicts (`has_conflict: true`)
- Toggle: exclude from stats

**Show page sections**:
- Personal info (name, email, phone, DOB, age)
- Registrations table: edition, ateliers, price paid, workshop overrides
- Orders summary
- "Mineur seul" badge + responsible person note if applicable

No creation from the UI (participants arrive via HelloAsso or CSV import).

---

### Orders (Commandes)

| Route | Controller#action | Description |
|---|---|---|
| `GET /orders` | `orders#index` | Paginated list |
| `GET /orders/:id` | `orders#show` | Order detail with all registrations |

Filters: date range, status, promo code.

---

### Workshops (Ateliers)

| Route | Controller#action | Description |
|---|---|---|
| `GET /workshops` | `workshops#index` | List workshops for current edition |
| `GET /workshops/new` | `workshops#new` | New workshop form |
| `POST /workshops` | `workshops#create` | Create workshop |
| `GET /workshops/:id` | `workshops#show` | Workshop detail + roster |
| `GET /workshops/:id/edit` | `workshops#edit` | Edit form |
| `PATCH /workshops/:id` | `workshops#update` | Update workshop |
| `DELETE /workshops/:id` | `workshops#destroy` | Delete (only if no registrations) |

**Show page**:
- Workshop info (name, time slot, capacity, fill rate, revenue)
- Participant roster table (name, age category, phone, email)
- "Exporter la liste" button → CSV download
- "Télécharger le roster PDF" button → PDF download

---

### Workshop Substitutions (Changements d'atelier)

A dedicated page for reassigning a participant from one workshop to another.
**Not inline on the participant profile** — it is a standalone admin operation.

| Route | Controller#action | Description |
|---|---|---|
| `GET /workshop_substitutions` | `workshop_substitutions#index` | Search/select a participant |
| `GET /workshop_substitutions/new?registration_id=X` | `workshop_substitutions#new` | Substitution form for a registration |
| `POST /workshop_substitutions` | `workshop_substitutions#create` | Apply substitution |

**Flow**:
1. Admin searches for a participant by name or ticket number.
2. Selects the registration.
3. Sees their current workshop assignments.
4. For each time slot, can select a different workshop from a dropdown.
5. On submit: existing `registration_workshop` for that slot is deleted (or flagged),
   a new one is created with `is_override: true`.

---

### Staff Profiles

| Route | Controller#action | Description |
|---|---|---|
| `GET /staff_profiles` | `staff_profiles#index` | List all staff for current edition |
| `GET /staff_profiles/new` | `staff_profiles#new` | New staff profile form |
| `POST /staff_profiles` | `staff_profiles#create` | Create profile |
| `GET /staff_profiles/:id` | `staff_profiles#show` | Full profile + financial summary |
| `GET /staff_profiles/:id/edit` | `staff_profiles#edit` | Edit form |
| `PATCH /staff_profiles/:id` | `staff_profiles#update` | Update profile |
| `GET /staff_profiles/:id/fiche.pdf` | `staff_profiles#fiche` | Generate + stream PDF |

**Show page layout**:
```
┌──────────────────────────────────────────────────┐
│ Dossier #001 — Marie Dupont                       │
│ [Modifier] [Générer la fiche PDF]                 │
├──────────────────────────────────────────────────┤
│ INFORMATIONS GÉNÉRALES                           │
│ Mode de déplacement: Voiture  KM: 320            │
│ Taux kilométrique: 0,33 €/km (édition)           │
│ Indemnité: 200,00 €  Libellé: "Intervenante"     │
│ Frais fournitures: 45,00 €                       │
├──────────────────────────────────────────────────┤
│ RÉCAPITULATIF FINANCIER                          │
│ Total à payer à l'animateur:    345,60 €         │
│ Total pris en charge Psalmodia: 180,00 €         │
│ Total membres non pris en charge: 60,00 €        │
│ Total membres pris en charge:   25,00 €          │
│ Montant dû à l'animateur:       490,60 €         │
│ Total acomptes:                  50,00 €         │
│ Total versements:               200,00 €         │
│ SOLDE:                          240,60 €         │
│         → Psalmodia doit à l'animateur           │
├──────────────────────────────────────────────────┤
│ ACOMPTES [+ Ajouter]              (Turbo Frame)  │
│ 15/03/2026  50,00 €  [Supprimer]                 │
├──────────────────────────────────────────────────┤
│ VERSEMENTS [+ Ajouter]            (Turbo Frame)  │
│ 01/07/2026  200,00 €  [Supprimer]                │
└──────────────────────────────────────────────────┘
```

---

### Staff Advances (Acomptes)

Managed inline on the staff profile show page via Turbo Frames. No dedicated index page.

| Route | Controller#action | Description |
|---|---|---|
| `POST /staff_profiles/:staff_profile_id/staff_advances` | `staff_advances#create` | Add advance |
| `DELETE /staff_profiles/:staff_profile_id/staff_advances/:id` | `staff_advances#destroy` | Remove advance |

### Staff Payments (Versements)

Same pattern as advances.

| Route | Controller#action | Description |
|---|---|---|
| `POST /staff_profiles/:staff_profile_id/staff_payments` | `staff_payments#create` | Add payment |
| `DELETE /staff_profiles/:staff_profile_id/staff_payments/:id` | `staff_payments#destroy` | Remove payment |

---

### Exports

| Route | Controller#action | Description |
|---|---|---|
| `GET /exports` | `exports#index` | Export options page |
| `GET /exports/participants.csv` | `exports#participants` | Filtered participant list |
| `GET /exports/workshop_roster/:id.csv` | `exports#workshop_roster_csv` | Workshop roster CSV |
| `GET /exports/workshop_roster/:id.pdf` | `exports#workshop_roster_pdf` | Workshop roster PDF |
| `GET /exports/contacts.csv` | `exports#contacts` | Contacts grouped by order (Tableau CCG equivalent) |
| `GET /exports/mineurs_seuls.csv` | `exports#mineurs_seuls` | Unaccompanied minors list |

All CSV exports use `send_data` with `Content-Type: text/csv` and UTF-8 BOM for Excel
compatibility.

---

### Settings (Paramètres)

| Route | Controller#action | Description |
|---|---|---|
| `GET /editions/:id/edit` | `editions#edit` | Edit edition settings (incl. km_rate_cents) |

---

### Session / Auth

| Route | Description |
|---|---|
| `GET /users/sign_in` | Devise login page |
| `DELETE /users/sign_out` | Devise logout |
| `PATCH /session/edition` | Switch current edition (custom controller) |

---

## Turbo Frame Usage

| Frame ID | Location | Behaviour |
|---|---|---|
| `staff_advances` | Staff profile show | Add/remove advance rows without full-page reload |
| `staff_payments` | Staff profile show | Add/remove payment rows |
| `financial_summary` | Staff profile show | Recalculates totals after advance/payment change |
| `workshop_filter` | Workshop index | Filter form updates list inline |
| `participant_search` | Workshop substitution | Live search result list |

---

## Stimulus Controllers

| Controller | Purpose |
|---|---|
| `flash` | Auto-dismiss flash messages after 4 seconds |
| `filter-form` | Auto-submit filter forms on change (no submit button needed) |
| `confirm-delete` | Show native confirm dialog before DELETE actions |
| `edition-switcher` | Handle edition `<select>` change → form submit |
| `currency-input` | Format euro amount inputs (strip "€", convert comma to dot) |
| `autosave` | Per-field PATCH on blur; show inline success/error feedback |

---

## Auto-Save Pattern

Several pages use **per-field auto-save on blur** rather than a traditional form submit button.
This eliminates save/cancel buttons for frequently-edited fields and provides instant feedback.

### Pages and fields that use auto-save

| Page | Fields |
|---|---|
| Staff profile show/edit | `allowance_cents`, `allowance_label`, `km_traveled`, `transport_mode`, `supplies_cost_cents`, all accommodation/meals/tickets/member fields, `notes` |
| Registration show + inline in participant list | `excluded_from_stats` (checkbox), `is_unaccompanied_minor` (checkbox), `responsible_person_note` |
| Edition settings (`editions#edit`) | `km_rate_cents`, `name`, `start_date`, `end_date` |

### Interaction flow

1. Field renders with `data-controller="autosave"` and `data-action="blur->autosave#save"`.
2. On blur, the Stimulus controller sends `PATCH /<resource>/:id` with the single field as a
   form param.
3. Server calls the appropriate actor (e.g. `Actors::UpdateStaffField`).
4. Server responds with a **Turbo Stream**:
   - **Success**: clears `<div id="field_error_<field>">`, briefly shows "Sauvegardé ✓" indicator
     adjacent to the field. If the field affects computed totals (staff financials), also updates
     the `financial_summary` Turbo Frame.
   - **Failure**: populates `<div id="field_error_<field>">` with the error message in red.

### Inline error placement

Each auto-save field has an adjacent empty div:
```html
<div id="field_error_allowance_cents" class="text-red-600 text-sm mt-1"></div>
```
The Turbo Stream replaces this div's content. No flash banner is shown for auto-save errors.

### No save/cancel buttons on auto-save pages

Pages that exclusively use auto-save do **not** have a "Enregistrer" button. The only exception
is the initial creation form for a new staff profile or edition (where the record does not yet
exist and there is nothing to PATCH).

---

## Tailwind Conventions

- **Primary colour**: Indigo (`indigo-600` / `indigo-700` for hover)
- **Danger**: Red (`red-600`)
- **Success**: Green (`green-600`)
- **Table rows**: alternating `bg-white` / `bg-gray-50`
- **Section headers**: `text-sm font-semibold text-gray-500 uppercase tracking-wide`
- **Cards**: `bg-white rounded-lg shadow-sm border border-gray-200 p-6`
- **Buttons**:
  - Primary: `bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700`
  - Secondary: `bg-white text-gray-700 border border-gray-300 px-4 py-2 rounded hover:bg-gray-50`
  - Danger: `bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700`

---

## Responsive Behaviour

- Sidebar collapses to a hamburger menu on screens < `md` (768px).
- Tables scroll horizontally on small screens (`overflow-x-auto` wrapper).
- Cards stack vertically on mobile.
- The application is not optimised for mobile use — desktop is the primary target.
