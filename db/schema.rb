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

ActiveRecord::Schema[8.1].define(version: 2026_03_26_152408) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "cik", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "ticker", null: false
    t.datetime "updated_at", null: false
    t.index ["cik"], name: "index_companies_on_cik", unique: true
    t.index ["ticker"], name: "index_companies_on_ticker", unique: true
  end

  create_table "filings", force: :cascade do |t|
    t.string "accession_number", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "filing_date", null: false
    t.string "form_type", null: false
    t.jsonb "parsed_sections", default: {}
    t.date "period_of_report", null: false
    t.text "raw_html"
    t.datetime "updated_at", null: false
    t.index ["accession_number"], name: "index_filings_on_accession_number", unique: true
    t.index ["company_id", "form_type", "filing_date"], name: "index_filings_on_company_id_and_form_type_and_filing_date", unique: true
    t.index ["company_id"], name: "index_filings_on_company_id"
  end

  add_foreign_key "filings", "companies"
end
