class CreateStaffProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :staff_profiles do |t|
      t.references :person,  null: false, foreign_key: true
      t.references :edition, null: false, foreign_key: true
      t.integer  :dossier_number,                       null: false
      t.string   :internal_id
      t.string   :transport_mode
      t.decimal  :km_traveled,                          precision: 8, scale: 2, default: 0
      t.integer  :km_rate_override_cents
      t.integer  :allowance_cents,                      default: 0
      t.integer  :supplies_cost_cents,                  default: 0
      t.integer  :accommodation_cost_cents,             default: 0
      t.integer  :meals_cost_cents,                     default: 0
      t.integer  :tickets_cost_cents,                   default: 0
      t.integer  :member_uncovered_accommodation_cents, default: 0
      t.integer  :member_uncovered_meals_cents,         default: 0
      t.integer  :member_uncovered_tickets_cents,       default: 0
      t.integer  :member_covered_tickets_cents,         default: 0
      t.string   :allowance_label
      t.text     :notes

      t.timestamps
    end

    add_index :staff_profiles, [ :person_id, :edition_id ], unique: true
  end
end
