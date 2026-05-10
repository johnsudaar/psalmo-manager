class CreateEditions < ActiveRecord::Migration[7.2]
  def change
    create_table :editions do |t|
      t.string  :name,                 null: false
      t.integer :year,                 null: false
      t.date    :start_date,           null: false
      t.date    :end_date,             null: false
      t.string  :helloasso_form_slug
      t.string  :helloasso_form_type,  default: "Event"
      t.integer :km_rate_cents,        null: false, default: 33

      t.timestamps
    end

    add_index :editions, :year, unique: true
  end
end
