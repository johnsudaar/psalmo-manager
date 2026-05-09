class CreateRegistrations < ActiveRecord::Migration[7.2]
  def change
    create_table :registrations do |t|
      t.references :order,   null: false, foreign_key: true
      t.references :person,  null: false, foreign_key: true
      t.references :edition, null: false, foreign_key: true
      t.string  :helloasso_ticket_id,    null: false
      t.integer :age_category,           null: false
      t.integer :ticket_price_cents,     null: false, default: 0
      t.integer :discount_cents,         null: false, default: 0
      t.boolean :has_conflict,           null: false, default: false
      t.boolean :excluded_from_stats,    null: false, default: false
      t.boolean :is_unaccompanied_minor, null: false, default: false
      t.text    :responsible_person_note
      t.jsonb   :helloasso_raw

      t.timestamps
    end

    add_index :registrations, :helloasso_ticket_id, unique: true
  end
end
