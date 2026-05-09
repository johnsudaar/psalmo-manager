class AddHasWorkshopOverrideToRegistrations < ActiveRecord::Migration[7.2]
  def change
    add_column :registrations, :has_workshop_override, :boolean, null: false, default: false
  end
end
