class CreateRegistrationWorkshops < ActiveRecord::Migration[7.2]
  def change
    create_table :registration_workshops do |t|
      t.references :registration, null: false, foreign_key: true
      t.references :workshop,     null: false, foreign_key: true
      t.integer :price_paid_cents, null: false, default: 0
      t.boolean :is_override,      null: false, default: false

      t.timestamps
    end

    add_index :registration_workshops, [ :registration_id, :workshop_id ], unique: true
  end
end
