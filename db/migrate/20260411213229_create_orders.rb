class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :edition,            null: false, foreign_key: true
      t.bigint     :payer_id
      t.string     :helloasso_order_id, null: false
      t.datetime   :order_date,         null: false
      t.integer    :status,             null: false
      t.string     :promo_code
      t.integer    :promo_amount_cents, default: 0
      t.jsonb      :helloasso_raw

      t.timestamps
    end

    add_index :orders, :helloasso_order_id, unique: true
    add_index :orders, :payer_id
    add_foreign_key :orders, :people, column: :payer_id
  end
end
