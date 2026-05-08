class CreateCitySubmissionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :city_submission_events do |t|
      t.references :city_submission, null: false, foreign_key: true
      t.string :event_type, null: false
      t.json :payload
      t.text :message

      t.timestamps
    end
  end
end
