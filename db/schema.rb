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

ActiveRecord::Schema.define(version: 2018_12_23_231943) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "announcements", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "issue", null: false
    t.string "locale", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "stickiness", default: 0, null: false
    t.bigint "staff_id", null: false
    t.datetime "published_at"
    t.integer "revision", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id", "issue", "id"], name: "index_announcements_on_conference_id_and_issue_and_id"
    t.index ["conference_id", "issue", "locale"], name: "index_announcements_on_conference_id_and_issue_and_locale", unique: true
    t.index ["conference_id", "issue", "revision"], name: "index_announcements_on_conference_id_and_issue_and_revision"
    t.index ["conference_id", "locale", "stickiness", "id"], name: "idx_user_listing"
    t.index ["conference_id"], name: "index_announcements_on_conference_id"
    t.index ["staff_id"], name: "index_announcements_on_staff_id"
  end

  create_table "conferences", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "application_opens_at"
    t.datetime "application_closes_at"
    t.datetime "amendment_closes_at"
    t.integer "booth_capacity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "contact_email_address"
    t.string "slug"
    t.index ["application_opens_at"], name: "index_conferences_on_application_opens_at"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "sponsorship_id", null: false
    t.integer "kind", null: false
    t.string "email", null: false
    t.string "address", null: false
    t.string "organization", null: false
    t.string "unit"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email", "kind", "sponsorship_id"], name: "index_contacts_on_email_and_kind_and_sponsorship_id"
    t.index ["sponsorship_id", "kind"], name: "index_contacts_on_sponsorship_id_and_kind", unique: true
    t.index ["sponsorship_id"], name: "index_contacts_on_sponsorship_id"
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

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "domain", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_organizations_on_domain", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "name", null: false
    t.integer "rank", default: 0, null: false
    t.string "summary"
    t.integer "capacity", null: false
    t.integer "number_of_guests", default: 0, null: false
    t.integer "booth_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "talkable"
    t.string "price_text"
    t.integer "words_limit"
    t.index ["conference_id", "rank"], name: "index_plans_on_conference_id_and_rank"
    t.index ["conference_id"], name: "index_plans_on_conference_id"
  end

  create_table "session_tokens", force: :cascade do |t|
    t.string "handle", null: false
    t.string "email"
    t.bigint "sponsorship_id"
    t.bigint "staff_id"
    t.boolean "user_initiated", default: true
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_session_tokens_on_handle", unique: true
    t.index ["sponsorship_id"], name: "index_session_tokens_on_sponsorship_id"
    t.index ["staff_id"], name: "index_session_tokens_on_staff_id"
  end

  create_table "sponsorship_asset_files", force: :cascade do |t|
    t.bigint "sponsorship_id"
    t.string "prefix", null: false
    t.string "handle", null: false
    t.string "extension"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_sponsorship_asset_files_on_handle"
    t.index ["sponsorship_id"], name: "index_sponsorship_asset_files_on_sponsorship_id"
  end

  create_table "sponsorship_editing_histories", force: :cascade do |t|
    t.bigint "sponsorship_id", null: false
    t.bigint "staff_id"
    t.string "comment"
    t.jsonb "diff", null: false
    t.jsonb "raw", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsorship_id", "id"], name: "index_sponsorship_editing_histories_on_sponsorship_id_and_id"
    t.index ["sponsorship_id"], name: "index_sponsorship_editing_histories_on_sponsorship_id"
    t.index ["staff_id"], name: "index_sponsorship_editing_histories_on_staff_id"
  end

  create_table "sponsorship_requests", force: :cascade do |t|
    t.bigint "sponsorship_id", null: false
    t.integer "kind", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsorship_id", "kind"], name: "index_sponsorship_requests_on_sponsorship_id_and_kind", unique: true
    t.index ["sponsorship_id"], name: "index_sponsorship_requests_on_sponsorship_id"
  end

  create_table "sponsorship_staff_notes", force: :cascade do |t|
    t.bigint "sponsorship_id", null: false
    t.bigint "staff_id", null: false
    t.integer "stickiness", default: 0, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsorship_id", "stickiness", "created_at"], name: "the_index"
    t.index ["sponsorship_id"], name: "index_sponsorship_staff_notes_on_sponsorship_id"
    t.index ["staff_id"], name: "index_sponsorship_staff_notes_on_staff_id"
  end

  create_table "sponsorships", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "plan_id"
    t.string "locale", null: false
    t.boolean "customization", default: false, null: false
    t.string "customization_name"
    t.string "name", null: false
    t.string "url", null: false
    t.text "profile", null: false
    t.boolean "booth_requested", default: false, null: false
    t.boolean "booth_assigned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "suspended", default: false, null: false
    t.index ["conference_id", "organization_id"], name: "index_sponsorships_on_conference_id_and_organization_id", unique: true
    t.index ["conference_id"], name: "index_sponsorships_on_conference_id"
    t.index ["organization_id"], name: "index_sponsorships_on_organization_id"
    t.index ["plan_id"], name: "index_sponsorships_on_plan_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.string "login", null: false
    t.string "name", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "avatar_url"
    t.index ["login"], name: "index_staffs_on_login", unique: true
    t.index ["uid"], name: "index_staffs_on_uid", unique: true
  end

  add_foreign_key "announcements", "conferences"
  add_foreign_key "announcements", "staffs"
  add_foreign_key "contacts", "sponsorships"
  add_foreign_key "form_descriptions", "conferences"
  add_foreign_key "plans", "conferences"
  add_foreign_key "sponsorship_asset_files", "sponsorships"
  add_foreign_key "sponsorship_editing_histories", "sponsorships"
  add_foreign_key "sponsorship_editing_histories", "staffs"
  add_foreign_key "sponsorship_staff_notes", "sponsorships"
  add_foreign_key "sponsorship_staff_notes", "staffs"
  add_foreign_key "sponsorships", "conferences"
  add_foreign_key "sponsorships", "organizations"
  add_foreign_key "sponsorships", "plans"
end
