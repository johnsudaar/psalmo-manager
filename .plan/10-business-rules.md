# 10 — Business Rules

This document defines all domain-specific logic that must be correctly implemented across models,
services, importers, and the PDF generator. When in doubt about a computation or threshold, this
file is the source of truth.

---

## Age Categories

Age is computed at the **start date of the edition** (`edition.start_date`), not at the time of
registration.

| Category | Enum value | Age range | Ticket price (2026) |
|---|---|---|---|
| `petit` | 0 | 0–5 ans (< 6) | 0 € |
| `enfant` | 1 | 6–9 ans (6 ≤ age < 10) | 40 € |
| `pre_ado` | 2 | 10–13 ans (10 ≤ age < 14) | 40 € |
| `ado` | 3 | 14–17 ans (14 ≤ age < 18) | 100 € |
| `adulte` | 4 | 18+ ans (age ≥ 18) | 100 € |

**Important**: Prices listed above are for the 2026 edition. They may change in future editions.
Prices are stored per `Registration` (as `ticket_price_cents`) and not re-computed from the
category — the HelloAsso API and CSV export provide the actual charged amount.

### Age computation method

```ruby
def age_on(date)
  return nil unless date_of_birth
  years = date.year - date_of_birth.year
  years -= 1 if date < date_of_birth + years.years
  years
end
```

### Category inference (for import)

```ruby
def self.age_category_for(age)
  case age
  when 0..5  then :petit
  when 6..9  then :enfant
  when 10..13 then :pre_ado
  when 14..17 then :ado
  else            :adulte
  end
end
```

If `date_of_birth` is nil (not provided), default to `:adulte` and flag for manual review.

---

## Workshop Time Slots

| Slot | Enum value | Description |
|---|---|---|
| `matin` | 0 | Morning session |
| `apres_midi` | 1 | Afternoon session |
| `journee` | 2 | Full-day session (counts as both matin + apres_midi) |

**Constraint**: A participant cannot be enrolled in two workshops with conflicting slots.
- A `journee` workshop conflicts with any other workshop on the same day.
- A `matin` workshop conflicts with another `matin` workshop.
- A `matin` workshop does NOT conflict with an `apres_midi` workshop.

**Enforcement**: This constraint is validated at the `Registration` model level and also enforced
in the workshop substitution controller.

```ruby
# In Registration model
validate :no_conflicting_workshops

def no_conflicting_workshops
  workshops.group_by(&:time_slot).each do |slot, ws|
    if slot == "journee" && workshops.count > 1
      errors.add(:base, "Un atelier journée ne peut pas être combiné avec un autre atelier")
    end
    if ws.count > 1
      errors.add(:base, "Deux ateliers ne peuvent pas avoir le même créneau horaire")
    end
  end
  if workshops.any? { |w| w.time_slot == "journee" } && workshops.count > 1
    errors.add(:base, "Un atelier journée occupe toute la journée")
  end
end
```

---

## Workshop Capacity

- `capacity: nil` means the workshop is unlimited.
- `capacity: N` means at most N participants.
- The `Workshop#full?` method returns true when `registrations.count >= capacity`.
- **Enforcement**: The UI warns when a workshop is full but does not hard-block manual overrides
  by an admin. (`is_override: true` bypasses capacity checks.)

---

## Workshop Substitution Rules

1. Only admins can perform substitutions (no self-service).
2. A substitution replaces the participant's workshop in a given time slot.
3. The old `registration_workshop` is deleted (not marked as inactive — it's gone).
4. The new `registration_workshop` is created with `is_override: true`.
5. If the new workshop has different pricing, `price_paid_cents` is set to the workshop's
   `base_price_cents` unless the admin manually overrides it.
6. Capacity check: warn if the target workshop is full, but allow admin to proceed.

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
edition.registrations.for_stats.sum(:actual_price_cents)
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
`registrations.actual_price_cents` in the HelloAsso data — do not double-count.

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
total_member_covered = member_covered_tickets_cents
```

### Amount owed TO the instructor (Montant dû à l'animateur)

```
amount_owed_to_instructor = total_to_pay
                          + total_psalmodia_covers
                          - total_member_uncovered
                          + total_member_covered
```

This represents the net amount Psalmodia owes the instructor before accounting for any payments
already made.

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
