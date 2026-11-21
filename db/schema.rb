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

ActiveRecord::Schema[8.1].define(version: 2026_11_21_233720) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clients", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "name_kana"
    t.string "postal_code"
    t.string "address"
    t.string "phone"
    t.string "email"
    t.string "contact_person"
    t.text "payment_terms"
    t.string "registration_number"
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_clients_on_tenant_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.integer "unit_price", default: 0, null: false
    t.string "unit"
    t.string "tax_rate", default: "standard", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_items_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_items_on_tenant_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "invoice_registration_number"
    t.string "postal_code"
    t.string "address"
    t.string "phone"
    t.string "email"
    t.string "document_number_prefix", default: "", null: false
    t.string "tax_rounding", default: "floor", null: false
    t.string "tax_display", default: "exclusive", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "item_code_counter", default: 0, null: false
  end

  create_table "users", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "disabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  add_foreign_key "clients", "tenants"
  add_foreign_key "items", "tenants"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "tenants"
end
