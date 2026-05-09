class AddWorkshopOverrideBackupToRegistrations < ActiveRecord::Migration[7.2]
  def change
    add_column :registrations, :workshop_override_backup, :jsonb, null: false, default: []
  end
end
