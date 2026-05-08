class AddImageValidationToCandidatePotholes < ActiveRecord::Migration[8.1]
  def change
    add_column :candidate_potholes, :image_validation_status, :integer, null: false, default: 0
    add_column :candidate_potholes, :image_validation_results, :json
    add_column :candidate_potholes, :image_validation_error, :text
    add_column :candidate_potholes, :image_validated_at, :datetime

    add_index :candidate_potholes, :image_validation_status
  end
end
