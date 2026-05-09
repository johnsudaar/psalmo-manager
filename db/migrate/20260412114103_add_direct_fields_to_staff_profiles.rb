class AddDirectFieldsToStaffProfiles < ActiveRecord::Migration[7.2]
  def change
    add_column :staff_profiles, :first_name, :string
    add_column :staff_profiles, :last_name, :string
    add_column :staff_profiles, :email, :string
    add_column :staff_profiles, :phone, :string
  end
end
