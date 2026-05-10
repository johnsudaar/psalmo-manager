# 03 — Data Model

## Overview

The database has **10 tables** (plus the PaperTrail `versions` table). All monetary values are
stored as **integer cents**. All tables have `created_at` and `updated_at` timestamps (Rails
default).

**Audit log**: Every model includes `has_paper_trail skip: [:updated_at], skip_unchanged: true`.
The `versions` table is created by `rails generate paper_trail:install`. `whodunnit` is set to
`current_user.email` via `ApplicationController#user_for_paper_trail`. Note: PaperTrail 15+
does not have `track_associations` config — association tracking is disabled by default.

---

## ER Diagram (text)

```
editions
  |
  |-- has_many --> workshops
  |-- has_many --> orders
  |-- has_many --> registrations (through orders)
  |-- has_many --> staff_profiles
  |-- has_many --> people (through registrations)

people
  |-- has_many --> registrations
  |-- has_many --> orders (as payer)
  |-- has_one  --> staff_profile

orders
  |-- belongs_to --> edition
  |-- belongs_to --> person (payer)
  |-- has_many   --> registrations

registrations
  |-- belongs_to --> order
  |-- belongs_to --> person
  |-- belongs_to --> edition
  |-- has_many   --> registration_workshops

workshops
  |-- belongs_to --> edition
  |-- has_many   --> registration_workshops

registration_workshops
  |-- belongs_to --> registration
  |-- belongs_to --> workshop

staff_profiles
  |-- belongs_to --> person
  |-- belongs_to --> edition
  |-- has_many   --> staff_advances
  |-- has_many   --> staff_payments

staff_advances
  |-- belongs_to --> staff_profile

staff_payments
  |-- belongs_to --> staff_profile
```

---

## Table Definitions

### `editions`

Represents one year's camp.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `name` | string | NOT NULL | e.g. "Psalmodia 2026" |
| `year` | integer | NOT NULL, UNIQUE | e.g. 2026 |
| `start_date` | date | NOT NULL | |
| `end_date` | date | NOT NULL | |
| `helloasso_form_slug` | string | | e.g. "psalmodia-2026" |
| `helloasso_form_type` | string | default: "Event" | HelloAsso form type |
| `km_rate_cents` | integer | NOT NULL, default: 33 | Travel rate in cents/km (0,33 €/km) |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `year` (unique)

**Model notes**:
```ruby
class Edition < ApplicationRecord
  has_paper_trail skip: [:updated_at], skip_unchanged: true

  has_many :workshops, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :registrations, through: :orders
  has_many :staff_profiles, dependent: :destroy

  validates :name, :year, :start_date, :end_date, presence: true
  validates :year, uniqueness: true
  validates :km_rate_cents, numericality: { greater_than: 0 }

  scope :ordered, -> { order(year: :desc) }

  def current?
    Edition.order(year: :desc).first == self
  end
end
```

---

### `workshops`

A single workshop offered during an edition.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `edition_id` | bigint | NOT NULL, FK | |
| `name` | string | NOT NULL | e.g. "CIRQUE", "THÉATRE ENFANTS" |
| `time_slot` | integer | NOT NULL | enum: matin/apres_midi/journee |
| `capacity` | integer | | nil = unlimited |
| `helloasso_column_name` | string | | raw column name from Sheet 1 CSV |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `edition_id`; `[edition_id, name]` (unique)

**Enums**:
```ruby
enum :time_slot, { matin: 0, apres_midi: 1, journee: 2 }
```

**Model notes**:
```ruby
class Workshop < ApplicationRecord
  has_paper_trail skip: [:updated_at], skip_unchanged: true

  belongs_to :edition
  has_many :registration_workshops, dependent: :destroy
  has_many :registrations, through: :registration_workshops

  enum :time_slot, { matin: 0, apres_midi: 1, journee: 2 }

  validates :name, :time_slot, presence: true
  validates :name, uniqueness: { scope: :edition_id }

  def fill_rate
    return nil if capacity.nil? || capacity.zero?
    (registrations.count.to_f / capacity * 100).round(1)
  end

  def full?
    capacity.present? && registrations.count >= capacity
  end
end
```

---

### `people`

A single person record. Covers participants, instructors, organisers, and staff.
One person may appear in multiple editions via multiple registrations.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `last_name` | string | NOT NULL | |
| `first_name` | string | NOT NULL | |
| `email` | string | | |
| `phone` | string | | |
| `date_of_birth` | date | | |
| `address` | text | | |
| `helloasso_payer_id` | string | | HelloAsso payer identifier |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `email`; `helloasso_payer_id`

**Model notes**:
```ruby
class Person < ApplicationRecord
  has_paper_trail skip: [:updated_at], skip_unchanged: true

  has_many :registrations, dependent: :destroy
  has_many :orders, foreign_key: :payer_id, dependent: :nullify
  has_one  :staff_profile, dependent: :destroy

  validates :last_name, :first_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def age_on(date)
    return nil unless date_of_birth
    years = date.year - date_of_birth.year
    years -= 1 if date < date_of_birth + years.years
    years
  end
end
```

---

### `orders`

A HelloAsso order (one per family/group checkout).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `edition_id` | bigint | NOT NULL, FK | |
| `payer_id` | bigint | FK → people | may be null if payer not yet resolved |
| `helloasso_order_id` | string | NOT NULL, UNIQUE | HelloAsso internal ID |
| `order_date` | datetime | NOT NULL | |
| `status` | integer | NOT NULL | enum: pending/confirmed/cancelled/refunded |
| `promo_code` | string | | |
| `promo_amount_cents` | integer | default: 0 | |
| `helloasso_raw` | jsonb | | raw API response for debugging |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `helloasso_order_id` (unique); `edition_id`; `payer_id`

**Enums**:
```ruby
enum :status, { pending: 0, confirmed: 1, cancelled: 2, refunded: 3 }
```

---

### `registrations`

One record per participant per edition. Corresponds to one HelloAsso ticket (billet).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `order_id` | bigint | NOT NULL, FK | |
| `person_id` | bigint | NOT NULL, FK | |
| `edition_id` | bigint | NOT NULL, FK | |
| `helloasso_ticket_id` | string | NOT NULL, UNIQUE | HelloAsso ticket ID |
| `age_category` | integer | NOT NULL | enum: enfant/adulte |
| `ticket_price_cents` | integer | NOT NULL, default: 0 | base ticket price |
| `discount_cents` | integer | NOT NULL, default: 0 | promo/reduction applied |
| `has_conflict` | boolean | NOT NULL, default: false | true = overlapping workshop slots flagged for admin review |
| `excluded_from_stats` | boolean | NOT NULL, default: false | manual exclusion from dashboards |
| `is_unaccompanied_minor` | boolean | NOT NULL, default: false | |
| `responsible_person_note` | text | | free text, e.g. "Responsabilité Elisabeth Lemmel" |
| `helloasso_raw` | jsonb | | raw API response for debugging |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `helloasso_ticket_id` (unique); `edition_id`; `person_id`; `order_id`

**Enums**:
```ruby
enum :age_category, { enfant: 0, adulte: 1 }
```

**Model notes**:
```ruby
class Registration < ApplicationRecord
  has_paper_trail skip: [:updated_at], skip_unchanged: true

  belongs_to :order
  belongs_to :person
  belongs_to :edition
  has_many :registration_workshops, dependent: :destroy
  has_many :workshops, through: :registration_workshops

  enum :age_category, { enfant: 0, adulte: 1 }

  validates :helloasso_ticket_id, presence: true, uniqueness: true
  validates :age_category, presence: true

  scope :for_stats, -> { where(excluded_from_stats: false) }
  scope :unaccompanied_minors, -> { where(is_unaccompanied_minor: true) }
  scope :with_conflicts, -> { where(has_conflict: true) }

  def actual_price_cents
    ticket_price_cents - discount_cents
  end
end
```

---

### `registration_workshops`

Join table: one row per (registration × workshop) pair.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `registration_id` | bigint | NOT NULL, FK | |
| `workshop_id` | bigint | NOT NULL, FK | |
| `price_paid_cents` | integer | NOT NULL, default: 0 | may differ from workshop base price |
| `is_override` | boolean | NOT NULL, default: false | true = manually substituted |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `[registration_id, workshop_id]` (unique); `workshop_id`

---

### `staff_profiles`

Financial profile for a staff member (instructor or organiser) for a given edition.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `person_id` | bigint | FK | optional link to an existing `Person` |
| `edition_id` | bigint | NOT NULL, FK | |
| `dossier_number` | integer | NOT NULL | auto-assigned sequential per edition |
| `first_name` | string | | direct entry when no linked `Person` |
| `last_name` | string | | direct entry when no linked `Person` |
| `email` | string | | direct entry when no linked `Person` |
| `phone` | string | | direct entry when no linked `Person` |
| `internal_id` | string | | e.g. "001_", matches Sheet 2 identifier |
| `transport_mode` | string | | e.g. "Voiture", "Train" |
| `km_traveled` | decimal(8,2) | default: 0 | |
| `km_rate_override_cents` | integer | | overrides edition km_rate_cents if set |
| `allowance_cents` | integer | default: 0 | indemnités animateur |
| `supplies_cost_cents` | integer | default: 0 | frais fournitures atelier |
| `accommodation_cost_cents` | integer | default: 0 | hébergement pris en charge Psalmodia |
| `meals_cost_cents` | integer | default: 0 | repas pris en charge Psalmodia |
| `tickets_cost_cents` | integer | default: 0 | billets/ateliers pris en charge Psalmodia |
| `member_uncovered_accommodation_cents` | integer | default: 0 | hébergement non pris en charge |
| `member_uncovered_meals_cents` | integer | default: 0 | repas non pris en charge |
| `member_uncovered_tickets_cents` | integer | default: 0 | billets non pris en charge |
| `member_covered_tickets_cents` | integer | default: 0 | billets membres pris en charge Psalmodia |
| `allowance_label` | string | | nom de l'indemnité (descriptive label) |
| `notes` | text | | commentaires libres |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `[person_id, edition_id]` (unique where `person_id IS NOT NULL`); `edition_id`; `person_id`

**Model notes** (computed fields — see `.plan/10-business-rules.md` for formulas):
```ruby
class StaffProfile < ApplicationRecord
  has_paper_trail skip: [:updated_at], skip_unchanged: true

  belongs_to :person, optional: true
  belongs_to :edition
  has_many :staff_advances, dependent: :destroy
  has_many :staff_payments, dependent: :destroy

  validates :dossier_number, presence: true, uniqueness: { scope: :edition_id }
  validates :last_name, :first_name, presence: true, unless: -> { person.present? }
  validate :person_or_direct_fields

  before_create :assign_dossier_number

  def full_name
    person ? person.full_name : "#{first_name} #{last_name}".strip
  end

  def display_email
    person&.email || email
  end

  def display_phone
    person&.phone || phone
  end

  def effective_km_rate_cents
    km_rate_override_cents || edition.km_rate_cents
  end

  def travel_allowance_cents
    (km_traveled * effective_km_rate_cents).round
  end

  def total_to_pay_instructor_cents
    allowance_cents + travel_allowance_cents + supplies_cost_cents
  end

  def total_psalmodia_covers_cents
    accommodation_cost_cents + meals_cost_cents + tickets_cost_cents
  end

  def total_member_uncovered_cents
    member_uncovered_accommodation_cents +
      member_uncovered_meals_cents +
      member_uncovered_tickets_cents
  end

  def total_member_covered_cents
    member_covered_tickets_cents
  end

  def amount_owed_to_instructor_cents
    total_to_pay_instructor_cents +
      total_psalmodia_covers_cents -
      total_member_uncovered_cents +
      total_member_covered_cents
  end

  def total_advances_cents
    staff_advances.sum(:amount_cents)
  end

  def total_payments_cents
    staff_payments.sum(:amount_cents)
  end

  def balance_cents
    amount_owed_to_instructor_cents - total_advances_cents - total_payments_cents
  end

  def psalmodia_owes?
    balance_cents > 0
  end

  def instructor_owes?
    balance_cents < 0
  end

  private

  def person_or_direct_fields
    return if person.present? || (first_name.present? && last_name.present?)

    errors.add(:base, "Un animateur doit être lié à une personne ou avoir un nom et prénom saisis directement")
  end

  def assign_dossier_number
    max = edition.staff_profiles.maximum(:dossier_number) || 0
    self.dossier_number = max + 1
  end
end
```

---

### `staff_advances`

An advance payment made by the instructor to Psalmodia (acompte).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `staff_profile_id` | bigint | NOT NULL, FK | |
| `date` | date | NOT NULL | |
| `amount_cents` | integer | NOT NULL | |
| `comment` | string | | |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `staff_profile_id`

---

### `staff_payments`

A disbursement made by Psalmodia to the instructor (versement).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK | |
| `staff_profile_id` | bigint | NOT NULL, FK | |
| `date` | date | NOT NULL | |
| `amount_cents` | integer | NOT NULL | |
| `comment` | string | | |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

**Indexes**: `staff_profile_id`

---

## Migration Order

Migrations must be created in this order to respect foreign key dependencies:

1. `versions` ← generated by `rails generate paper_trail:install` (no FK dependencies)
2. `editions`
3. `workshops` (FK → editions)
4. `people`
5. `orders` (FK → editions, people)
6. `registrations` (FK → orders, people, editions)
7. `registration_workshops` (FK → registrations, workshops)
8. `staff_profiles` (FK → people, editions)
9. `staff_advances` (FK → staff_profiles)
10. `staff_payments` (FK → staff_profiles)

---

## Notes on Design Decisions

- **Two age categories only**: `enfant` and `adulte`. Psalmodia does not need sub-categories
  (petit, pre_ado, ado). Simpler enum, simpler code, simpler UI.

- **No `registration_week` column**: The week of registration can be computed from `order_date`
  when needed. Storing it would be premature denormalisation.

- **No `actual_price_cents` column**: Computed as `ticket_price_cents - discount_cents` via a
  model method. The revenue query uses `sum("ticket_price_cents - discount_cents")` directly in
  SQL. No need to store a value that is pure arithmetic of two other columns on the same row.

- **No `base_price_cents` on workshops**: The actual price paid is stored on
  `registration_workshops.price_paid_cents`. A separate "base price" was not asked for.

- **`has_conflict` flag instead of hard block**: When a participant has overlapping workshop
  slots, the registration is saved with `has_conflict: true` for admin review. The import/sync
  never refuses data — it flags it.

- **Person is not split into Participant/Instructor**: A single `people` table with no role column
  avoids duplication. The same person can attend as a participant in one edition and as staff in
  another. Role context comes from whether they have a `registration` and/or a `staff_profile`.

- **edition_id on registrations is denormalised**: It is derivable via `order.edition_id` but
  having it directly on `registrations` simplifies scoping queries significantly.

- **jsonb columns for raw API data**: `orders.helloasso_raw` and `registrations.helloasso_raw`
  store the full HelloAsso API response. This is useful for debugging discrepancies without
  re-hitting the API.

- **km_rate_override on staff_profiles**: The edition-level `km_rate_cents` is the default.
  Setting `km_rate_override_cents` on a profile overrides it for that person only (e.g. a cyclist
  vs a car driver may have different rates).
