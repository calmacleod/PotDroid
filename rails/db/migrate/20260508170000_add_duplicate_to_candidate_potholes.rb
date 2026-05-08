class AddDuplicateToCandidatePotholes < ActiveRecord::Migration[8.1]
  def change
    add_reference :candidate_potholes,
      :duplicate_of,
      foreign_key: { to_table: :candidate_potholes },
      index: true
  end
end
