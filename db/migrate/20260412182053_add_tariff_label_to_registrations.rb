class AddTariffLabelToRegistrations < ActiveRecord::Migration[7.2]
  def change
    add_column :registrations, :tariff_label, :string
  end
end
