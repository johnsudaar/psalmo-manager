# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_04_12_140002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "editions", force: :cascade do |t|
    t.string "name", null: false
    t.integer "year", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "helloasso_form_slug"
    t.string "helloasso_form_type", default: "Event"
    t.integer "km_rate_cents", default: 33, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "transport_modes"
    t.text "allowance_labels"
    t.index ["year"], name: "index_editions_on_year", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "edition_id", null: false
    t.bigint "payer_id"
    t.string "helloasso_order_id", null: false
    t.datetime "order_date", null: false
    t.integer "status", null: false
    t.string "promo_code"
    t.integer "promo_amount_cents", default: 0
    t.jsonb "helloasso_raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id"], name: "index_orders_on_edition_id"
    t.index ["helloasso_order_id"], name: "index_orders_on_helloasso_order_id", unique: true
    t.index ["payer_id"], name: "index_orders_on_payer_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "last_name", null: false
    t.string "first_name", null: false
    t.string "email"
    t.string "phone"
    t.date "date_of_birth"
    t.text "address"
    t.string "helloasso_payer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_people_on_email"
    t.index ["helloasso_payer_id"], name: "index_people_on_helloasso_payer_id"
  end

  create_table "registration_workshops", force: :cascade do |t|
    t.bigint "registration_id", null: false
    t.bigint "workshop_id", null: false
    t.integer "price_paid_cents", default: 0, null: false
    t.boolean "is_override", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["registration_id", "workshop_id"], name: "idx_on_registration_id_workshop_id_acc070b9a3", unique: true
    t.index ["registration_id"], name: "index_registration_workshops_on_registration_id"
    t.index ["workshop_id"], name: "index_registration_workshops_on_workshop_id"
  end

  create_table "registrations", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "person_id", null: false
    t.bigint "edition_id", null: false
    t.string "helloasso_ticket_id", null: false
    t.integer "age_category", null: false
    t.integer "ticket_price_cents", default: 0, null: false
    t.integer "discount_cents", default: 0, null: false
    t.boolean "has_conflict", default: false, null: false
    t.boolean "excluded_from_stats", default: false, null: false
    t.boolean "is_unaccompanied_minor", default: false, null: false
    t.text "responsible_person_note"
    t.jsonb "helloasso_raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id"], name: "index_registrations_on_edition_id"
    t.index ["helloasso_ticket_id"], name: "index_registrations_on_helloasso_ticket_id", unique: true
    t.index ["order_id"], name: "index_registrations_on_order_id"
    t.index ["person_id"], name: "index_registrations_on_person_id"
  end

  create_table "staff_advances", force: :cascade do |t|
    t.bigint "staff_profile_id", null: false
    t.date "date", null: false
    t.integer "amount_cents", null: false
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_profile_id"], name: "index_staff_advances_on_staff_profile_id"
  end

  create_table "staff_payments", force: :cascade do |t|
    t.bigint "staff_profile_id", null: false
    t.date "date", null: false
    t.integer "amount_cents", null: false
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_profile_id"], name: "index_staff_payments_on_staff_profile_id"
  end

  create_table "staff_profiles", force: :cascade do |t|
    t.bigint "person_id"
    t.bigint "edition_id", null: false
    t.integer "dossier_number", null: false
    t.string "internal_id"
    t.string "transport_mode"
    t.decimal "km_traveled", precision: 8, scale: 2, default: "0.0"
    t.integer "km_rate_override_cents"
    t.integer "allowance_cents", default: 0
    t.integer "supplies_cost_cents", default: 0
    t.integer "accommodation_cost_cents", default: 0
    t.integer "meals_cost_cents", default: 0
    t.integer "tickets_cost_cents", default: 0
    t.integer "member_uncovered_accommodation_cents", default: 0
    t.integer "member_uncovered_meals_cents", default: 0
    t.integer "member_uncovered_tickets_cents", default: 0
    t.integer "member_covered_tickets_cents", default: 0
    t.string "allowance_label"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.index ["edition_id"], name: "index_staff_profiles_on_edition_id"
    t.index ["person_id", "edition_id"], name: "index_staff_profiles_on_person_id_and_edition_id", unique: true, where: "(person_id IS NOT NULL)"
    t.index ["person_id"], name: "index_staff_profiles_on_person_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "workshops", force: :cascade do |t|
    t.bigint "edition_id", null: false
    t.string "name", null: false
    t.integer "time_slot", null: false
    t.integer "capacity"
    t.string "helloasso_column_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id", "name"], name: "index_workshops_on_edition_id_and_name", unique: true
    t.index ["edition_id"], name: "index_workshops_on_edition_id"
  end

  add_foreign_key "orders", "editions"
  add_foreign_key "orders", "people", column: "payer_id"
  add_foreign_key "registration_workshops", "registrations"
  add_foreign_key "registration_workshops", "workshops"
  add_foreign_key "registrations", "editions"
  add_foreign_key "registrations", "orders"
  add_foreign_key "registrations", "people"
  add_foreign_key "staff_advances", "staff_profiles"
  add_foreign_key "staff_payments", "staff_profiles"
  add_foreign_key "staff_profiles", "editions"
  add_foreign_key "staff_profiles", "people"
  add_foreign_key "workshops", "editions"
end
