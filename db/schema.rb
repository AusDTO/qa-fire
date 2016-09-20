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

ActiveRecord::Schema.define(version: 20160920020742) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "deploys", force: :cascade do |t|
    t.string   "name"
    t.integer  "project_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "trigger"
    t.json     "data"
    t.integer  "remote_reference"
    t.string   "branch"
    t.string   "sha"
    t.index ["project_id"], name: "index_deploys_on_project_id", using: :btree
  end

  create_table "projects", force: :cascade do |t|
    t.string   "repository"
    t.string   "webhook_secret"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.json     "data"
    t.integer  "user_id"
    t.index ["user_id"], name: "index_projects_on_user_id", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",               default: "", null: false
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",       default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.string   "provider"
    t.string   "uid"
    t.string   "github_token"
    t.string   "username"
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, using: :btree
  end

  add_foreign_key "deploys", "projects"
  add_foreign_key "projects", "users"
end
