class CreateCitySubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :city_submissions do |t|
      t.references :candidate_pothole, null: false, foreign_key: true
      t.string :connector, null: false
      t.integer :status, default: 0, null: false
      t.string :external_request_id
      t.string :external_status
      t.datetime :submitted_at
      t.datetime :last_checked_at
      t.json :response_payload
      t.text :error_message

      t.timestamps
    end

    add_index :city_submissions, :status
    add_index :city_submissions, :external_request_id
  end
end
