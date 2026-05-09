class AddTravelOverrideToStaffProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :staff_profiles, :travel_override_cents, :integer
  end
end
