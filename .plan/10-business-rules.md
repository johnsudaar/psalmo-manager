# 10 — Business Rules

This document defines all domain-specific logic that must be correctly implemented across models,
services, importers, and the PDF generator. When in doubt about a computation or threshold, this
file is the source of truth.

---

## Age Categories

A participant is either a **child** (`enfant`) or an **adult** (`adulte`). Age is determined
from `date_of_birth` relative to `edition.start_date`.

| Category | Enum value | Rule |
|---|---|---|
| `enfant` | 0 | Under 18 on edition start date, OR date_of_birth unknown |
| `adulte` | 1 | 18 or over on edition start date |

**Missing DOB**: Default to `enfant`. At Psalmodia most participants are children; an unknown age
is safer treated as a child for pricing and safeguarding.

### Category inference

```ruby
def self.age_category_for(date_of_birth, edition_start_date)
  return :enfant if date_of_birth.nil?
  age = edition_start_date.year - date_of_birth.year
  age -= 1 if edition_start_date < date_of_birth + age.years
  age >= 18 ? :adulte : :enfant
end
```

If `date_of_birth` is nil (not provided), default to `:enfant` and flag for manual review.
This is a conservative choice: at Psalmodia most participants are children, so an unknown age
should be treated as a child (not an adult) for pricing and safety purposes.

---

## Workshop Time Slots

| Slot | Enum value | Description |
|---|---|---|
| `matin` | 0 | Morning session |
| `apres_midi` | 1 | Afternoon session |
| `journee` | 2 | Full-day session |

**Conflict detection**: When a participant is enrolled in two workshops with overlapping slots
(two `matin`, two `apres_midi`, or any workshop alongside a `journee`), set
`registration.has_conflict = true`. This is a flag for admin review — the import and sync never
refuse or delete data because of slot conflicts.

```ruby
# In Registration model
def detect_conflict!
  slots = workshops.map(&:time_slot)
  conflicting = slots.tally.any? { |_, count| count > 1 } ||
                (slots.include?("journee") && slots.size > 1)
  update_column(:has_conflict, conflicting)
end
```

Admins see registrations with `has_conflict: true` highlighted in the participant list and can
resolve them via the workshop substitution page.

---

## Workshop Capacity

- `capacity: nil` means the workshop is unlimited.
- `capacity: N` means at most N participants.
- The `Workshop#full?` method returns true when `registrations.count >= capacity`.
- The UI shows a warning when a workshop is full. Admins can always proceed regardless.

---

## Workshop Substitution Rules

1. Only admins can perform substitutions (no self-service).
2. A substitution replaces the participant's workshop in a given time slot.
3. The old `registration_workshop` is deleted (not marked as inactive — it's gone).
4. The new `registration_workshop` is created with `is_override: true`.
5. After the substitution, `detect_conflict!` is called on the registration to update
   the `has_conflict` flag.
6. If the target workshop is full, a warning is shown but the admin can still proceed.

---

## Statistics Exclusion

Any `Registration` with `excluded_from_stats: true` is excluded from:

- Total participant count on the dashboard
- Revenue totals (billetterie + ateliers)
- Age distribution chart
- Workshop fill rates (for the purpose of dashboard stats — the participant still appears on the
  roster)
- Weekly registration cadence

**Important**: Excluded registrations still appear on:
- Participant detail page
- Workshop rosters (they physically attended)
- Export lists (unless the export specifically filters them)

Scope: `Registration.for_stats` returns `where(excluded_from_stats: false)`.

---

## Revenue Computation

### Total billetterie revenue (edition)

```ruby
edition.registrations.for_stats.sum("ticket_price_cents - discount_cents")
```

### Total atelier revenue (edition)

```ruby
RegistrationWorkshop
  .joins(registration: :edition)
  .merge(Registration.for_stats)
  .where(registrations: { edition_id: edition.id })
  .sum(:price_paid_cents)
```

### Total general revenue

```
total_billetterie + total_ateliers
```

Note: Promo codes (`orders.promo_amount_cents`) are already deducted from
`registrations.discount_cents` in the HelloAsso data — do not double-count.

---

## Staff Financial Formulas

All values are in euro **cents**. See `.plan/03-data-model.md` for field definitions.

### Travel allowance

```
travel_allowance_cents = round(km_traveled × effective_km_rate_cents)
```

Where:
- `effective_km_rate_cents = km_rate_override_cents || edition.km_rate_cents`
- Round to nearest integer cent (use `.round`)
- `km_traveled` is a `decimal(8,2)` — can have half-km precision

### Total to pay to instructor (Frais animateur à payer Psalmodia)

```
total_to_pay = allowance_cents + travel_allowance_cents + supplies_cost_cents
```

### Total Psalmodia covers (Frais animateur pris en charge)

```
total_psalmodia_covers = accommodation_cost_cents + meals_cost_cents + tickets_cost_cents
```

### Total member costs not covered (Frais membres non pris en charge)

```
total_member_uncovered = member_uncovered_accommodation_cents
                       + member_uncovered_meals_cents
                       + member_uncovered_tickets_cents
```

### Total member costs covered by Psalmodia (Frais membres pris en charge)

```
total_member_covered = member_covered_accommodation_cents
                     + member_covered_meals_cents
                     + member_covered_tickets_cents
```

### Amount owed TO the instructor (Montant dû à l'animateur)

```
amount_owed_to_instructor = total_to_pay - total_member_uncovered
```

`total_psalmodia_covers` and `total_member_covered` are **informational only** — they appear in
the PDF and UI but do not affect the balance calculation. They represent costs Psalmodia directly
bears (accommodation, meals, tickets) and are not flows of cash between Psalmodia and the
instructor.

### Balance (Solde)

```
balance = amount_owed_to_instructor - total_advances - total_payments
```

Where:
- `total_advances = staff_advances.sum(:amount_cents)` (amounts the instructor paid TO Psalmodia)
- `total_payments = staff_payments.sum(:amount_cents)` (amounts Psalmodia paid TO the instructor)

### Interpreting the balance

| Balance | Meaning |
|---|---|
| `balance > 0` | **Psalmodia owes** the instructor `balance` cents |
| `balance < 0` | **The instructor owes** Psalmodia `balance.abs` cents |
| `balance == 0` | Settled |

### Displayed on the PDF as

```
Somme à payer à l'animateur = balance         (if balance > 0)
Somme à payer à Psalmodia   = balance.abs     (if balance < 0)
```

---

## Dossier Number Assignment

`dossier_number` is an auto-assigned sequential integer per edition, starting at 1.

```ruby
def assign_dossier_number
  max = edition.staff_profiles.maximum(:dossier_number) || 0
  self.dossier_number = max + 1
end
```

This runs as a `before_create` callback. It is **not** protected against race conditions in a
concurrent environment — if two staff profiles are created simultaneously for the same edition,
there could be a collision. For this application (single admin user, low concurrency), this is
acceptable. If needed, use a database sequence or advisory lock.

---

## Promo Codes

Promo codes are stored on `orders.promo_code` (string) and `orders.promo_amount_cents` (cents).

A promo code is applied at the order level and reduces the total order amount. Individual
registration `discount_cents` values reflect the per-item portion of the promo.

The application **does not manage** promo codes — it only displays and imports them.
HelloAsso is the source of truth for discount amounts.

---

## Unaccompanied Minors

An unaccompanied minor is a participant who:
- Is under 18 years old at the edition start date, AND
- Attends without a parent or legal guardian

Rules:
- `is_unaccompanied_minor: true` is set manually by an admin or by the CSV importer.
- `responsible_person_note` is a free-text field (e.g. "Responsabilité Elisabeth Lemmel").
  It does **not** link to a `Person` record.
- Unaccompanied minors appear in a dedicated list (accessible from the dashboard and the exports
  page).
- There is no automated detection — this is a manual flag.

---

## Edition Switching

The current edition is stored in `session[:edition_id]`. All controllers read it via:

```ruby
def current_edition
  @current_edition ||= Edition.find_by(id: session[:edition_id]) ||
                       Edition.order(year: :desc).first
end
helper_method :current_edition
```

If no edition exists yet, `current_edition` returns nil and all scoped queries should handle this
gracefully (return empty collections, not raise errors).

---

## CSV Export Conventions

- **Encoding**: UTF-8 with BOM (`"\xEF\xBB\xBF"`) for Excel compatibility on Windows.
- **Delimiter**: comma (`,`)
- **Date format**: `DD/MM/YYYY` (French convention)
- **Amount format**: `50,00 €` (comma as decimal separator, space before €)
- **Boolean**: `Oui` / `Non`
- **Empty values**: empty string (no `NULL` or `nil` text)
- **Filename**: snake_case with edition year suffix, e.g. `participants_2026.csv`

---

## Km Reimbursement Rate

The default rate is stored on `edition.km_rate_cents` (in cents per km).

- Default value: `33` (= 0,33 €/km — approximate French fiscal rate for 2025/2026)
- This is configurable per edition via the edition edit form.
- Individual overrides are stored on `staff_profiles.km_rate_override_cents`.
- When `km_rate_override_cents` is set, it takes precedence over the edition rate for that staff
  member only.
- The PDF fiche shows the effective rate and marks it as "(taux personnalisé)" if overridden.

**Note on the actual French fiscal rate**: The official barème kilométrique varies by vehicle type
and annual km. For simplicity, the application uses a single flat rate. The association can update
it annually via the edition settings.
