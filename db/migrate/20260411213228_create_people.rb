class CreatePeople < ActiveRecord::Migration[7.2]
  def change
    create_table :people do |t|
      t.string :last_name,          null: false
      t.string :first_name,         null: false
      t.string :email
      t.string :phone
      t.date   :date_of_birth
      t.text   :address
      t.string :helloasso_payer_id

      t.timestamps
    end

    add_index :people, :email
    add_index :people, :helloasso_payer_id
  end
end
