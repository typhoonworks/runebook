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

ActiveRecord::Schema[8.1].define(version: 2026_01_24_100616) do
  create_table "notebooks", force: :cascade do |t|
    t.integer "autosave_interval", default: 30000
    t.datetime "created_at", null: false
    t.boolean "dirty", default: false, null: false
    t.string "file_path", null: false
    t.string "format", default: "runemd", null: false
    t.datetime "last_saved_at"
    t.string "title", default: "Untitled notebook", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["file_path"], name: "index_notebooks_on_file_path", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "evaluation_count", default: 0
    t.datetime "last_evaluation_at"
    t.integer "notebook_id", null: false
    t.integer "pid"
    t.boolean "setup_cell_evaluated", default: false
    t.datetime "started_at"
    t.string "status", default: "open", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["last_evaluation_at"], name: "index_sessions_on_last_evaluation_at"
    t.index ["notebook_id"], name: "index_sessions_on_notebook_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
  end

  add_foreign_key "sessions", "notebooks"
end
