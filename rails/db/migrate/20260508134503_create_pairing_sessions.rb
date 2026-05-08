class CreatePairingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :pairing_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :api_token, null: true, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :claimed_at
      t.string :device_name

      t.timestamps
    end

    add_index :pairing_sessions, :expires_at
    add_index :pairing_sessions, :claimed_at
  end
end
