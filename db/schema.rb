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

ActiveRecord::Schema[8.1].define(version: 2026_11_21_235601) do
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

  create_table "document_deliveries", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "document_id", null: false
    t.string "channel", null: false
    t.string "recipient_email", null: false
    t.datetime "sent_at", null: false
    t.string "token_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_deliveries_on_document_id"
    t.index ["tenant_id"], name: "index_document_deliveries_on_tenant_id"
  end

  create_table "document_lines", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "item_id"
    t.string "name", null: false
    t.decimal "quantity", precision: 12, scale: 2, null: false
    t.string "unit"
    t.integer "unit_price", default: 0, null: false
    t.string "tax_rate", default: "standard", null: false
    t.integer "position", default: 0, null: false
    t.integer "amount", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_lines_on_document_id"
    t.index ["item_id"], name: "index_document_lines_on_item_id"
  end

  create_table "document_sequences", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "kind", null: false
    t.string "year_month", null: false
    t.integer "last_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "kind", "year_month"], name: "index_document_sequences_on_tenant_id_and_kind_and_year_month", unique: true
    t.index ["tenant_id"], name: "index_document_sequences_on_tenant_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "client_id", null: false
    t.string "kind", null: false
    t.string "number", null: false
    t.date "issue_date", null: false
    t.date "due_date"
    t.string "title"
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.bigint "converted_from_id"
    t.integer "subtotal", default: 0, null: false
    t.integer "tax_amount", default: 0, null: false
    t.integer "total", default: 0, null: false
    t.jsonb "tax_breakdown", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_status"
    t.index ["client_id"], name: "index_documents_on_client_id"
    t.index ["converted_from_id"], name: "index_documents_on_converted_from_id"
    t.index ["tenant_id", "kind", "number"], name: "index_documents_on_tenant_id_and_kind_and_number", unique: true
    t.index ["tenant_id", "kind"], name: "index_documents_on_tenant_id_and_kind"
    t.index ["tenant_id"], name: "index_documents_on_tenant_id"
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

  create_table "payments", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "document_id", null: false
    t.integer "amount", null: false
    t.date "paid_on", null: false
    t.string "method", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_payments_on_document_id"
    t.index ["tenant_id"], name: "index_payments_on_tenant_id"
  end

  create_table "recurring_documents", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "client_id", null: false
    t.bigint "template_document_id", null: false
    t.integer "day_of_month", null: false
    t.boolean "active", default: true, null: false
    t.boolean "auto_send", default: false, null: false
    t.date "last_run_date"
    t.date "next_run_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_recurring_documents_on_client_id"
    t.index ["template_document_id"], name: "index_recurring_documents_on_template_document_id"
    t.index ["tenant_id"], name: "index_recurring_documents_on_tenant_id"
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
  add_foreign_key "document_deliveries", "documents"
  add_foreign_key "document_deliveries", "tenants"
  add_foreign_key "document_lines", "documents"
  add_foreign_key "document_lines", "items"
  add_foreign_key "document_sequences", "tenants"
  add_foreign_key "documents", "clients"
  add_foreign_key "documents", "documents", column: "converted_from_id"
  add_foreign_key "documents", "tenants"
  add_foreign_key "items", "tenants"
  add_foreign_key "payments", "documents"
  add_foreign_key "payments", "tenants"
  add_foreign_key "recurring_documents", "clients"
  add_foreign_key "recurring_documents", "documents", column: "template_document_id"
  add_foreign_key "recurring_documents", "tenants"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "tenants"
end
