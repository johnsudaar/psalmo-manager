class CreateWorkshops < ActiveRecord::Migration[7.2]
  def change
    create_table :workshops do |t|
      t.references :edition, null: false, foreign_key: true
      t.string  :name,                  null: false
      t.integer :time_slot,             null: false
      t.integer :capacity
      t.string  :helloasso_column_name

      t.timestamps
    end

    add_index :workshops, [ :edition_id, :name ], unique: true
  end
end
