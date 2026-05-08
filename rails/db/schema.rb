# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_08_124532) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token_prefix"], name: "index_api_tokens_on_token_prefix", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "candidate_potholes", force: :cascade do |t|
    t.json "bounding_box"
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.decimal "detector_confidence", precision: 5, scale: 4, null: false
    t.string "detector_model_version"
    t.decimal "heading", precision: 6, scale: 2
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.decimal "speed", precision: 6, scale: 2
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["captured_at"], name: "index_candidate_potholes_on_captured_at"
    t.index ["reviewed_by_id"], name: "index_candidate_potholes_on_reviewed_by_id"
    t.index ["status"], name: "index_candidate_potholes_on_status"
    t.index ["user_id"], name: "index_candidate_potholes_on_user_id"
  end

  create_table "city_submission_events", force: :cascade do |t|
    t.integer "city_submission_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "message"
    t.json "payload"
    t.datetime "updated_at", null: false
    t.index ["city_submission_id"], name: "index_city_submission_events_on_city_submission_id"
  end

  create_table "city_submissions", force: :cascade do |t|
    t.integer "candidate_pothole_id", null: false
    t.string "connector", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "external_request_id"
    t.string "external_status"
    t.datetime "last_checked_at"
    t.json "response_payload"
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["candidate_pothole_id"], name: "index_city_submissions_on_candidate_pothole_id"
    t.index ["external_request_id"], name: "index_city_submissions_on_external_request_id"
    t.index ["status"], name: "index_city_submissions_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "candidate_potholes", "users"
  add_foreign_key "candidate_potholes", "users", column: "reviewed_by_id"
  add_foreign_key "city_submission_events", "city_submissions"
  add_foreign_key "city_submissions", "candidate_potholes"
  add_foreign_key "sessions", "users"
end
