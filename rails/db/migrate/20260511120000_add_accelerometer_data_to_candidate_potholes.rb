class AddAccelerometerDataToCandidatePotholes < ActiveRecord::Migration[8.1]
  def change
    add_column :candidate_potholes, :accelerometer_data, :json
  end
end
