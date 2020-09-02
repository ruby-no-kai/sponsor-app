# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_08_26_203120) do

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
    t.boolean "exhibitors_only", default: false, null: false
    t.index ["conference_id", "issue", "id"], name: "index_announcements_on_conference_id_and_issue_and_id"
    t.index ["conference_id", "issue", "locale"], name: "index_announcements_on_conference_id_and_issue_and_locale", unique: true
    t.index ["conference_id", "issue", "revision"], name: "index_announcements_on_conference_id_and_issue_and_revision"
    t.index ["conference_id", "locale", "stickiness", "id"], name: "idx_user_listing"
    t.index ["conference_id"], name: "index_announcements_on_conference_id"
    t.index ["staff_id"], name: "index_announcements_on_staff_id"
  end

  create_table "broadcast_deliveries", force: :cascade do |t|
    t.bigint "broadcast_id", null: false
    t.bigint "sponsorship_id"
    t.string "recipient", null: false
    t.integer "status", null: false
    t.jsonb "meta"
    t.datetime "dispatched_at"
    t.datetime "opened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_cc"
    t.index ["broadcast_id", "id"], name: "index_broadcast_deliveries_on_broadcast_id_and_id"
    t.index ["broadcast_id", "status"], name: "index_broadcast_deliveries_on_broadcast_id_and_status"
    t.index ["broadcast_id"], name: "index_broadcast_deliveries_on_broadcast_id"
    t.index ["recipient"], name: "index_broadcast_deliveries_on_recipient"
    t.index ["sponsorship_id"], name: "index_broadcast_deliveries_on_sponsorship_id"
  end

  create_table "broadcasts", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.string "campaign", null: false
    t.text "description", null: false
    t.integer "status", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.bigint "staff_id", null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "dispatched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id", "campaign"], name: "index_broadcasts_on_conference_id_and_campaign", unique: true
    t.index ["conference_id", "id"], name: "index_broadcasts_on_conference_id_and_id"
    t.index ["conference_id"], name: "index_broadcasts_on_conference_id"
    t.index ["staff_id"], name: "index_broadcasts_on_staff_id"
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
    t.boolean "additional_attendees_registration_open", default: false, null: false
    t.string "github_repo"
    t.string "reception_key", null: false
    t.datetime "ticket_distribution_starts_at"
    t.boolean "hidden", default: false, null: false
    t.string "invite_code"
    t.boolean "no_plan_allowed", default: true, null: false
    t.boolean "allow_restricted_access"
    t.index ["application_opens_at"], name: "index_conferences_on_application_opens_at"
    t.index ["slug"], name: "index_conferences_on_slug", unique: true
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
    t.string "email_cc"
    t.index ["email", "kind", "sponsorship_id"], name: "index_contacts_on_email_and_kind_and_sponsorship_id"
    t.index ["sponsorship_id", "kind"], name: "index_contacts_on_sponsorship_id_and_kind", unique: true
    t.index ["sponsorship_id"], name: "index_contacts_on_sponsorship_id"
  end

  create_table "exhibition_editing_histories", force: :cascade do |t|
    t.bigint "exhibition_id"
    t.bigint "staff_id"
    t.string "comment"
    t.jsonb "diff"
    t.jsonb "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibition_id", "id"], name: "index_exhibition_editing_histories_on_exhibition_id_and_id"
    t.index ["exhibition_id"], name: "index_exhibition_editing_histories_on_exhibition_id"
    t.index ["staff_id"], name: "index_exhibition_editing_histories_on_staff_id"
  end

  create_table "exhibitions", force: :cascade do |t|
    t.bigint "sponsorship_id"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sponsorship_id"], name: "index_exhibitions_on_sponsorship_id"
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
    t.text "ticket_help"
    t.text "ticket_help_html"
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
    t.boolean "auto_acceptance", default: true, null: false
    t.datetime "closes_at"
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
    t.integer "number_of_additional_attendees"
    t.datetime "withdrawn_at"
    t.string "ticket_key", null: false
    t.datetime "accepted_at"
    t.index ["conference_id", "organization_id"], name: "index_sponsorships_on_conference_id_and_organization_id", unique: true
    t.index ["conference_id", "ticket_key"], name: "index_sponsorships_on_conference_id_and_ticket_key", unique: true
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
    t.string "restricted_repos"
    t.index ["login"], name: "index_staffs_on_login", unique: true
    t.index ["uid"], name: "index_staffs_on_uid", unique: true
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.bigint "sponsorship_id", null: false
    t.integer "kind", null: false
    t.string "code", null: false
    t.string "handle", null: false
    t.string "name", null: false
    t.string "email"
    t.boolean "authorized", default: false, null: false
    t.datetime "checked_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id", "code"], name: "index_tickets_on_conference_id_and_code", unique: true
    t.index ["conference_id", "handle"], name: "index_tickets_on_conference_id_and_handle", unique: true
    t.index ["conference_id"], name: "index_tickets_on_conference_id"
    t.index ["sponsorship_id", "kind", "checked_in_at"], name: "index_tickets_on_sponsorship_id_and_kind_and_checked_in_at"
    t.index ["sponsorship_id"], name: "index_tickets_on_sponsorship_id"
  end

  add_foreign_key "announcements", "conferences"
  add_foreign_key "announcements", "staffs"
  add_foreign_key "broadcast_deliveries", "broadcasts"
  add_foreign_key "broadcast_deliveries", "sponsorships"
  add_foreign_key "broadcasts", "conferences"
  add_foreign_key "broadcasts", "staffs"
  add_foreign_key "contacts", "sponsorships"
  add_foreign_key "exhibition_editing_histories", "exhibitions"
  add_foreign_key "exhibition_editing_histories", "staffs"
  add_foreign_key "exhibitions", "sponsorships"
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
  add_foreign_key "tickets", "conferences"
  add_foreign_key "tickets", "sponsorships"
end
