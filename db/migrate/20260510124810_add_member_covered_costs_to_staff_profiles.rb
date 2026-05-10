class AddMemberCoveredCostsToStaffProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :staff_profiles, :member_covered_accommodation_cents, :integer, default: 0, null: false
    add_column :staff_profiles, :member_covered_meals_cents, :integer, default: 0, null: false
  end
end
