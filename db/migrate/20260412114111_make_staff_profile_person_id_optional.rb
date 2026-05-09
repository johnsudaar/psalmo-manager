class MakeStaffProfilePersonIdOptional < ActiveRecord::Migration[7.2]
  def change
    # Remove the old unique index on (person_id, edition_id) — it doesn't handle NULL correctly.
    # A staff profile linked to a person is still unique per edition; profiles without a person
    # are not constrained by this index (NULL != NULL in SQL so the old index would allow
    # duplicates anyway). We keep the per-column index for FK lookup performance.
    remove_index :staff_profiles, name: "index_staff_profiles_on_person_id_and_edition_id"

    # Make person_id nullable
    change_column_null :staff_profiles, :person_id, true

    # Re-add the unique constraint only for rows that have a person_id (partial index)
    add_index :staff_profiles, [ :person_id, :edition_id ],
              unique: true,
              where: "person_id IS NOT NULL",
              name: "index_staff_profiles_on_person_id_and_edition_id"
  end
end
