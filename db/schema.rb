# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2018_11_04_214542) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conferences", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "application_opens_at"
    t.datetime "application_closes_at"
    t.datetime "amendment_closes_at"
    t.integer "booth_capacity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_opens_at"], name: "index_conferences_on_application_opens_at"
  end

  create_table "form_descriptions", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "locale", null: false
    t.text "head"
    t.text "head_html"
    t.text "plan_help"
    t.text "plan_help_html"
    t.text "booth_help"
    t.text "booth_help_html"
    t.text "policy_help"
    t.text "policy_help_html"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id", "locale"], name: "index_form_descriptions_on_conference_id_and_locale", unique: true
    t.index ["conference_id"], name: "index_form_descriptions_on_conference_id"
  end

  add_foreign_key "form_descriptions", "conferences"
end
