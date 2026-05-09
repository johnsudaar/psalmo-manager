class CreateStaffAdvances < ActiveRecord::Migration[7.2]
  def change
    create_table :staff_advances do |t|
      t.references :staff_profile, null: false, foreign_key: true
      t.date    :date,         null: false
      t.integer :amount_cents, null: false
      t.string  :comment

      t.timestamps
    end
  end
end
