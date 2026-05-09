# 05 — Data Sources

## Overview

Two Google Sheets provide historical data that must be migrated as a one-time import:

| Sheet | Purpose | Destination tables |
|---|---|---|
| **Sheet 1** — `1ZpJwY2877_Lf_RGFtDHaOu10Yexm8ae6ZuEGhzrTHnQ` | Participants, orders, workshops | `people`, `orders`, `registrations`, `registration_workshops` |
| **Sheet 2** — `153otRCsYrjY80UeBOHK7q2DHwApUbGtG0F5K5lHgSaY` | Staff financial tracking | `staff_profiles`, `staff_advances`, `staff_payments` |

Going forward, live data comes from the HelloAsso API (see `.plan/04-helloasso-integration.md`).

---

## Sheet 1 — Participants & Workshops

### Relevant tabs

| Tab name | gid | Use |
|---|---|---|
| `DONNES_BRUTES` | 458461397 | Raw HelloAsso export — source of truth for the CSV import |
| `DONNES_BRUTES_FILTREES` | 480593159 | Same + 3 computed columns (Inscription Semaine, Age, Age 10aine) |
| `FIltres` | 103030669 | Manual workshop overrides (ticket number + forced workshop) |
| `Calcul Statistiques` | 1311200823 | Ticket numbers excluded from stats |
| `Mineurs_Seuls` | 456758431 | Unaccompanied minors with responsible person note |

The other tabs (Listes, Recapitulatif, Tableau CCG, Liste Par Atelier) are derived/computed views
and do not need to be imported — the Rails app re-generates equivalent views.

---

### `DONNES_BRUTES` Column Structure

This tab is a raw HelloAsso export. Each row = one ticket (billet). The real export format used by
the importer differs slightly from the original draft below. The actual important columns are:

| Column header | Maps to | Notes |
|---|---|---|
| `Numéro de billet` | `registrations.helloasso_ticket_id` | Unique per row |
| `Référence commande` | `orders.helloasso_order_id` | Multiple rows may share this |
| `Nom participant` | `people.last_name` | Participant |
| `Prénom participant` | `people.first_name` | Participant |
| `N° de téléphone` | `people.phone` | participant phone |
| `Email payeur` | payer email | no participant email column in the real export |
| `Date de naissance` | `people.date_of_birth` | Format: DD/MM/YYYY |
| `Montant tarif` | `registrations.ticket_price_cents` | In euros, convert × 100 |
| `Montant code promo` | `registrations.discount_cents` | In euros, convert × 100 |
| `Date de la commande` | `orders.order_date` | Format: DD/MM/YYYY HH:MM |
| `Nom payeur` | payer last name | May differ from participant |
| `Prénom payeur` | payer first name | |
| `Email payeur` | payer email | |
| `Téléphone payeur` | payer phone | |
| `Code promo` | `orders.promo_code` | |
| `Montant code promo` | `orders.promo_amount_cents` | In euros, convert × 100 at order level when relevant |
| `Statut de la commande` | import guard | only rows with value `Validé` are imported |

**Workshop columns** in the real export use a pair of columns per workshop:
- `WORKSHOP_NAME` = `Oui` when selected
- `Montant WORKSHOP_NAME` = price paid for that workshop

The importer should create a `registration_workshop` when the workshop column value is `Oui`, and
read the paid amount from the corresponding `Montant ...` column.

**Derived columns in DONNES_BRUTES_FILTREES** (can be ignored — the app recomputes what it needs):
- `Age` — integer age at time of camp
- `Age 10aine` — age bracket string (not used; app uses enfant/adulte only)

---

### Workshop Column Pivot Logic

The raw export has one column per workshop. The importer must:

1. Identify which columns are workshop columns (by comparing to known workshop names or by
   detecting non-standard column headers).
2. For each row, iterate over workshop columns.
3. If a column value is non-empty and non-zero, create a `registration_workshop` record:
    - `workshop_id` — find or create `Workshop` by `(edition_id, name)`
    - `price_paid_cents` — parse the column value × 100
    - `is_override` — false (raw data, not a manual override)

---

### Payer vs Participant

Most rows have the same person as payer and participant. When `Nom payeur` / `Prénom payeur`
differ from `Nom` / `Prénom`:

1. Find or create a `Person` for the **participant** (using `Numéro de billet` as
   `helloasso_ticket_id`).
2. Find or create a separate `Person` for the **payer** (using email or name match).
3. Set `orders.payer_id` to the payer's person record.

When payer = participant (identical name + email), reuse the same `Person` record.

---

### FIltres Tab — Workshop Overrides

This tab has rows with:
- Column A: ticket number
- Columns B+: forced workshop assignments (one column per time slot override)

For each row:
1. Find the `Registration` by `helloasso_ticket_id`.
2. Remove any existing `registration_workshops` for the affected time slots.
3. Create new `registration_workshop` records with `is_override: true`.

---

### Calcul Statistiques Tab — Stat Exclusions

Contains a list of ticket numbers to exclude from statistics.

For each ticket number in this tab, find the `Registration` and set `excluded_from_stats: true`.

---

### Mineurs_Seuls Tab — Unaccompanied Minors

Each row contains:
- Ticket number or name
- Free-text note, e.g. "Responsabilité Elisabeth Lemmel"

For each row:
1. Find the `Registration`.
2. Set `is_unaccompanied_minor: true`.
3. Set `responsible_person_note` to the free-text content.

---

### CSV Import — Rake Task

```ruby
# lib/tasks/import_participants.rake
namespace :import do
  desc "Import participants from Sheet 1 CSV export"
  task :participants, [:csv_path, :edition_id] => :environment do |_t, args|
    importer = Importers::ParticipantsCsvImporter.new(
      csv_path:   args[:csv_path],
      edition_id: args[:edition_id].to_i
    )
    result = importer.call
    puts "Imported: #{result[:created]} created, #{result[:updated]} updated, #{result[:errors].count} errors"
    result[:errors].each { |e| puts "  ERROR: #{e}" }
  end
end
```

Usage:
```bash
rails import:participants[/path/to/donnes_brutes.csv,1]
```

Current Docker command:
```bash
docker compose exec app bundle exec rails "import:participants[/rails/import.csv,497]"
```

Testing/data hygiene notes:
- Fixture CSV files must use fictional names and `.example.test` email addresses only.
- When generating fixture CSV files with Ruby, prefer `CSV.open` to avoid quoting issues with
  headers and values containing commas.
- Do not commit `/rails/import.csv` or any ad-hoc root-level CSV file.

Test DB safety notes:
- Run imports and seeds with `docker compose exec app ...` (development env).
- Run tests with `docker compose exec -e RAILS_ENV=test app ...` only.
- If the test DB is polluted, reset it with:

```bash
docker compose exec -e RAILS_ENV=test app bundle exec rails db:schema:load
```

---

### Service Object Structure

```ruby
# app/services/importers/participants_csv_importer.rb
module Importers
  class ParticipantsCsvImporter
    WORKSHOP_COLUMN_BLACKLIST = %w[
      Numéro\ de\ billet Référence\ commande Nom\ participant Prénom\ participant
      N°\ de\ téléphone Date\ de\ naissance Date\ de\ la\ commande
      Nom\ payeur Prénom\ payeur Email\ payeur Téléphone\ payeur
      Code\ promo Montant\ code\ promo Statut\ de\ la\ commande
    ].freeze

    def initialize(csv_path:, edition_id:)
      @csv_path   = csv_path
      @edition_id = edition_id
      @edition    = Edition.find(edition_id)
      @created    = 0
      @updated    = 0
      @errors     = []
    end

    def call
      CSV.foreach(@csv_path, headers: true, encoding: "UTF-8") do |row|
        process_row(row)
      rescue => e
        @errors << "Row #{$.}: #{e.message}"
      end
      { created: @created, updated: @updated, errors: @errors }
    end

    private

    def workshop_columns(headers)
      headers.reject { |h| WORKSHOP_COLUMN_BLACKLIST.include?(h) }
    end

    def process_row(row)
      # 1. Find or create Person (participant)
      # 2. Find or create Person (payer) if different
      # 3. Find or create Order
      # 4. Find or create Registration
      # 5. For each workshop column with a value: find or create Workshop, create RegistrationWorkshop
    end
  end
end
```

---

## Sheet 2 — Staff Financial Tracking

### Sheet structure

**Tab: `Recapitulatif Frais Animateur`** (gid=0)

This is the main data tab. Columns:

| Column | Maps to |
|---|---|
| A — Identifiant | `staff_profiles.internal_id` (e.g. "001_") |
| B — Nom | `people.last_name` |
| C — Prénom | `people.first_name` |
| D — Mode de déplacement | `staff_profiles.transport_mode` |
| E — KM Parcourus | `staff_profiles.km_traveled` |
| F — Indemnités | `staff_profiles.allowance_cents` (× 100) |
| G — Frais de déplacement | computed — not imported directly (recalculated) |
| H — Frais fournitures atelier | `staff_profiles.supplies_cost_cents` (× 100) |
| I — Total (frais à payer) | computed — not imported |
| J — Hébergement (pris en charge) | `staff_profiles.accommodation_cost_cents` (× 100) |
| K — Repas (pris en charge) | `staff_profiles.meals_cost_cents` (× 100) |
| L — Billets/Ateliers (pris en charge) | `staff_profiles.tickets_cost_cents` (× 100) |
| M — Total (animateur pris en charge) | computed — not imported |
| N — Hébergement non pris en charge | `staff_profiles.member_uncovered_accommodation_cents` (× 100) |
| O — Repas non pris en charge | `staff_profiles.member_uncovered_meals_cents` (× 100) |
| P — Billets non pris en charge | `staff_profiles.member_uncovered_tickets_cents` (× 100) |
| Q — Total membres à payer | computed — not imported |
| R — Billets membres pris en charge | `staff_profiles.member_covered_tickets_cents` (× 100) |
| S — Total membres pris en charge | computed — not imported |
| T — À payer à l'animateur | computed — not imported |
| U — Montant reçu de l'animateur | sum of `staff_advances` — not imported as a single field |
| V — Solde | computed — not imported |
| W — Coût animateur | computed — not imported |
| X — Nom indemnité | `staff_profiles.allowance_label` |
| Y — Commentaires | `staff_profiles.notes` |

**Tab: `Versements`** (gid=441971600)

Columns: `De` (internal_id), `A` (internal_id of recipient), `Date`, `Montant`, `Commentaire`

Each row = one payment/advance. Disambiguate direction:
- If `De` is an internal_id matching a staff member → this is a `staff_advance` (instructor paid
  Psalmodia)
- If `A` is an internal_id matching a staff member → this is a `staff_payment` (Psalmodia paid
  instructor)

Import: create `StaffAdvance` or `StaffPayment` records accordingly.

---

### CSV Import — Rake Task

```ruby
# lib/tasks/import_staff.rake
namespace :import do
  desc "Import staff financial data from Sheet 2 CSV exports"
  task :staff, [:profiles_csv, :payments_csv, :edition_id] => :environment do |_t, args|
    Importers::StaffCsvImporter.new(
      profiles_csv: args[:profiles_csv],
      payments_csv: args[:payments_csv],
      edition_id:   args[:edition_id].to_i
    ).call
  end
end
```

---

## Import Order

When running the full migration for an edition:

1. `rails import:participants[donnes_brutes.csv,EDITION_ID]`
   — creates all people, orders, registrations, registration_workshops
2. Apply overrides from `FIltres` tab (separate CSV export or manual)
3. Apply stat exclusions from `Calcul Statistiques` tab
4. Apply unaccompanied minor flags from `Mineurs_Seuls` tab
5. `rails import:staff[recap_frais.csv,versements.csv,EDITION_ID]`
   — creates staff_profiles, staff_advances, staff_payments

---

## CSV Export Instructions (for the association admin)

To obtain the CSVs from Google Sheets:

1. Open the Google Sheet
2. Go to **File → Download → Comma-separated values (.csv)**
3. Repeat for each relevant tab
4. Save with UTF-8 encoding (Google Sheets exports UTF-8 by default)

Alternatively, use the Google Sheets API to export programmatically:
```
https://docs.google.com/spreadsheets/d/{SHEET_ID}/gviz/tq?tqx=out:csv&gid={GID}
```
(No authentication required if the sheet is publicly readable.)

---

## Data Quality Notes

- **Date formats**: Google Sheets exports dates as `DD/MM/YYYY`. The importer must parse with
  `Date.strptime(str, "%d/%m/%Y")`.
- **Euro amounts**: May be formatted as `"50,00 €"` or just `"50"`. Strip currency symbols and
  convert commas to dots before parsing.
- **Encoding**: Sheets exports are UTF-8 but may contain BOM — use `encoding: "bom|utf-8"` in
  `CSV.foreach`.
- **Missing date_of_birth**: Default `age_category` to `:enfant` (not `:adulte`). Psalmodia's
  participants are predominantly children; an unknown age is safer treated as a child for pricing
  and safeguarding purposes. Flag the registration in the import log for manual review.
- **Duplicate orders**: Multiple rows with the same `Référence commande` → same `Order` record,
  multiple `Registration` records.
- **Workshop column names**: May have accents, spaces, special characters. Normalise by
  stripping leading/trailing whitespace. Match case-insensitively when looking up `Workshop`
  records.
