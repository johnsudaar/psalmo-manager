# 11 — Actor Catalogue

## Overview

Every meaningful user-initiated write action is handled by a dedicated **actor** class using the
`interactor` gem. Controllers are thin: they call one actor, check `context.success?`, then either
redirect/render success or surface the inline error.

**Folder**: `app/actors/actors/` (module `Actors`)

**Protocol**:
- Input lives in `context` (set by the caller).
- Output lives in `context` (actors set result keys on success).
- On failure: `context.fail!(error: "message")`.
- Controllers never call model methods directly for writes — they call an actor.

See `.plan/02-technical-stack.md#actor-pattern` for the canonical usage example.

---

## Actor Index

| Actor class | Triggered by | Description |
|---|---|---|
| `Actors::ApplyWorkshopSubstitution` | `workshop_substitutions#create` | Reassign a registration to a different workshop; marks row `is_override: true` |
| `Actors::UpdateRegistrationOverride` | `registrations#update` (auto-save) | Toggle `excluded_from_stats`, `is_unaccompanied_minor`, or `responsible_person_note` |
| `Actors::UpdateStaffField` | `staff_profiles#update` (auto-save) | Update a single financial or metadata field on a staff profile |
| `Actors::UpdateEditionSettings` | `editions#update` (auto-save) | Update a single field on an edition (name, dates, km_rate_cents) |
| `Actors::AddStaffAdvance` | `staff_advances#create` | Add an acompte to a staff profile |
| `Actors::RemoveStaffAdvance` | `staff_advances#destroy` | Remove an acompte from a staff profile |
| `Actors::AddStaffPayment` | `staff_payments#create` | Add a versement to a staff profile |
| `Actors::RemoveStaffPayment` | `staff_payments#destroy` | Remove a versement from a staff profile |
| `Actors::TriggerHelloassoSync` | `dashboard#sync` or admin button | Enqueue `HelloassoSyncJob` for the current edition |
| `Actors::CreateWorkshop` | `workshops#create` | Create a new workshop for an edition |
| `Actors::UpdateWorkshop` | `workshops#update` | Update workshop attributes |
| `Actors::DestroyWorkshop` | `workshops#destroy` | Delete workshop (guards: no registrations) |
| `Actors::CreateStaffProfile` | `staff_profiles#create` | Create a staff profile; auto-assigns dossier_number |
| `Actors::CreateEdition` | `editions#create` | Create a new edition |

---

## Actor Specifications

### `Actors::ApplyWorkshopSubstitution`

**File**: `app/actors/actors/apply_workshop_substitution.rb`

**Context inputs**:
- `context.registration` — the `Registration` record
- `context.workshop` — the target `Workshop` record (the new workshop to assign)

> **Note**: the context key is `workshop:`, not `new_workshop:`. The controller
> (`workshop_substitutions#create`) passes `workshop: new_ws`.

**Context outputs** (on success):
- `context.registration_workshop` — the newly created `RegistrationWorkshop`

**Logic**:
1. Validate `workshop` belongs to the same edition as `registration`.
2. Find any existing `RegistrationWorkshop` for `registration` whose workshop has the same
   `time_slot` as the target workshop. Destroy it (whether `is_override` or not — manual
   substitution always wins).
3. Create a new `RegistrationWorkshop` with `is_override: true`.
4. `context.fail!` if the new record is invalid.

**Guard**: If `workshop.edition_id != registration.edition_id`, fail with "Atelier hors édition".

---

### `Actors::UpdateRegistrationOverride`

**File**: `app/actors/actors/update_registration_override.rb`

**Context inputs**:
- `context.registration` — the `Registration` record
- `context.field` — one of: `"excluded_from_stats"`, `"is_unaccompanied_minor"`,
  `"responsible_person_note"`
- `context.value` — the new value (string from the HTTP param; actor coerces booleans)

**Context outputs**: none beyond success/failure

**Logic**:
1. Reject any field not in the allowed list (`context.fail!` with "Champ non autorisé").
2. Cast value: `"true"/"1"` → `true`, `"false"/"0"` → `false` for boolean fields.
3. `registration.update(field => value)`.
4. `context.fail!(error: ...)` if validation fails.

**Note**: This actor only updates override-owned fields. Attempting to update a HelloAsso-owned
field (e.g. `first_name`) must be rejected.

---

### `Actors::UpdateStaffField`

**File**: `app/actors/actors/update_staff_field.rb`

**Context inputs**:
- `context.staff_profile` — the `StaffProfile` record
- `context.field` — the field name as a string
- `context.value` — the new value

**Context outputs**: none

**Allowed fields** (whitelist):
```
allowance_cents, allowance_label, km_traveled, km_rate_override_cents, transport_mode,
supplies_cost_cents, accommodation_cost_cents, meals_cost_cents, tickets_cost_cents,
member_uncovered_accommodation_cents, member_uncovered_meals_cents,
member_uncovered_tickets_cents, member_covered_accommodation_cents,
member_covered_meals_cents, member_covered_tickets_cents, notes
```

**Logic**:
1. Reject fields not in the whitelist.
2. Cast cents fields to integer.
3. `staff_profile.update(field => value)`.
4. Fail with validation errors on failure.

---

### `Actors::UpdateEditionSettings`

**File**: `app/actors/actors/update_edition_settings.rb`

**Context inputs**:
- `context.edition` — the `Edition` record
- `context.field` — field name
- `context.value` — new value

**Allowed fields**: `name`, `start_date`, `end_date`, `km_rate_cents`, `helloasso_form_slug`,
`helloasso_form_type`

**Logic**: Same whitelist-check-then-update pattern as `UpdateStaffField`.

---

### `Actors::AddStaffAdvance`

**File**: `app/actors/actors/add_staff_advance.rb`

**Context inputs**:
- `context.staff_profile`
- `context.date` — string "YYYY-MM-DD"
- `context.amount_cents` — integer
- `context.comment` — string (optional)

**Context outputs**:
- `context.staff_advance` — the created record

**Logic**: Build and save a `StaffAdvance`. Fail with validation errors if invalid.

---

### `Actors::RemoveStaffAdvance`

**File**: `app/actors/actors/remove_staff_advance.rb`

**Context inputs**:
- `context.staff_advance` — the `StaffAdvance` record

**Logic**: Destroy the record. Fail if destroy raises.

---

### `Actors::AddStaffPayment`

**File**: `app/actors/actors/add_staff_payment.rb`

Mirror of `AddStaffAdvance` for `StaffPayment`.

**Context outputs**:
- `context.staff_payment`

---

### `Actors::RemoveStaffPayment`

**File**: `app/actors/actors/remove_staff_payment.rb`

Mirror of `RemoveStaffAdvance` for `StaffPayment`.

---

### `Actors::TriggerHelloassoSync`

**File**: `app/actors/actors/trigger_helloasso_sync.rb`

**Context inputs**:
- `context.edition` — the edition to sync

**Logic**: Enqueue `HelloassoSyncJob.perform_later(edition.id)`.
Sets `context.job_id` on success for display feedback.

---

### `Actors::CreateWorkshop`

**File**: `app/actors/actors/create_workshop.rb`

**Context inputs**:
- `context.edition`
- `context.workshop_params` — permitted params hash

**Context outputs**:
- `context.workshop`

**Logic**: Build and save a `Workshop` scoped to the edition. Fail on validation error.

---

### `Actors::UpdateWorkshop`

**File**: `app/actors/actors/update_workshop.rb`

**Context inputs**:
- `context.workshop`
- `context.workshop_params`

**Logic**: `workshop.update(workshop_params)`. Fail on error.

---

### `Actors::DestroyWorkshop`

**File**: `app/actors/actors/destroy_workshop.rb`

**Context inputs**:
- `context.workshop`

**Guard**: If `workshop.registrations.any?`, fail with
"Impossible de supprimer un atelier avec des inscriptions."

**Logic**: Destroy the workshop.

---

### `Actors::CreateStaffProfile`

**File**: `app/actors/actors/create_staff_profile.rb`

**Context inputs**:
- `context.edition`
- `context.person` — the `Person` to associate (optional)
- `context.staff_profile_params` — permitted params hash

**Context outputs**:
- `context.staff_profile`

**Logic**:
1. Build `StaffProfile` from `staff_profile_params`.
2. Associate `context.person` if present.
3. Save the profile.
4. Fail with validation errors if neither an existing `Person` nor direct-entry name fields are
   provided.

This actor supports both creation modes:
- linked to an existing `Person`
- direct entry on `staff_profiles` (`first_name`, `last_name`, optional `email`, `phone`)

---

### `Actors::CreateEdition`

**File**: `app/actors/actors/create_edition.rb`

**Context inputs**:
- `context.edition_params`

**Context outputs**:
- `context.edition`

**Logic**: Build and save an `Edition`. Fail on validation error.

---

## Testing Actors

Each actor has a spec in `spec/actors/actors/`:

```
spec/actors/actors/apply_workshop_substitution_spec.rb
spec/actors/actors/update_registration_override_spec.rb
spec/actors/actors/update_staff_field_spec.rb
spec/actors/actors/update_edition_settings_spec.rb
spec/actors/actors/add_staff_advance_spec.rb
spec/actors/actors/remove_staff_advance_spec.rb
spec/actors/actors/add_staff_payment_spec.rb
spec/actors/actors/remove_staff_payment_spec.rb
spec/actors/actors/trigger_helloasso_sync_spec.rb
spec/actors/actors/create_workshop_spec.rb
spec/actors/actors/update_workshop_spec.rb
spec/actors/actors/destroy_workshop_spec.rb
spec/actors/actors/create_staff_profile_spec.rb
spec/actors/actors/create_edition_spec.rb
```

Each spec covers:
1. Happy path: success?, correct output on `context`
2. Failure path: `context.failure?`, correct `context.error` message
3. Guard conditions (whitelist rejection, cross-edition guard, etc.)
