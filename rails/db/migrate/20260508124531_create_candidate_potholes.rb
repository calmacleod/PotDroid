class CreateCandidatePotholes < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_potholes do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.decimal :heading, precision: 6, scale: 2
      t.decimal :speed, precision: 6, scale: 2
      t.decimal :detector_confidence, precision: 5, scale: 4, null: false
      t.string :detector_model_version
      t.json :bounding_box
      t.datetime :captured_at, null: false
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :candidate_potholes, :status
    add_index :candidate_potholes, :captured_at
  end
end
