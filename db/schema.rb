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

ActiveRecord::Schema[8.0].define(version: 2026_01_12_192206) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "import_runs", force: :cascade do |t|
    t.integer "total_lines", default: 0, null: false
    t.integer "successful_records", default: 0, null: false
    t.jsonb "validation_errors", default: [], null: false
    t.jsonb "warnings", default: [], null: false
    t.jsonb "statistics", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_import_runs_on_created_at"
    t.index ["status"], name: "index_import_runs_on_status"
  end

  create_table "records", force: :cascade do |t|
    t.bigint "import_run_id", null: false
    t.string "resource_id", null: false
    t.string "resource_type", null: false
    t.string "subject_reference"
    t.jsonb "extracted_data", default: {}, null: false
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "next_of_kin", default: {}
    t.index ["extracted_data"], name: "index_records_on_extracted_data", using: :gin
    t.index ["import_run_id"], name: "index_records_on_import_run_id"
    t.index ["resource_id", "resource_type"], name: "index_record_on_resource_id_and_type", unique: true
    t.index ["resource_type", "subject_reference"], name: "index_record_on_type_and_subject"
    t.index ["resource_type"], name: "index_records_on_resource_type"
    t.index ["subject_reference"], name: "index_records_on_subject_reference"
  end

  add_foreign_key "records", "import_runs"
end
