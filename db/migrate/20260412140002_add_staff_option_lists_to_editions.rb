class AddStaffOptionListsToEditions < ActiveRecord::Migration[7.2]
  def change
    add_column :editions, :transport_modes, :text
    add_column :editions, :allowance_labels, :text
  end
end
