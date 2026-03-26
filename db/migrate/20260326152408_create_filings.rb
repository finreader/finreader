class CreateFilings < ActiveRecord::Migration[8.1]
  def change
    create_table :filings do |t|
      t.references :company, null: false, foreign_key: true
      t.string :form_type, null: false
      t.date :filing_date, null: false
      t.date :period_of_report, null: false
      t.string :accession_number, null: false
      t.text :raw_html
      t.jsonb :parsed_sections, default: {}

      t.timestamps
    end
    add_index :filings, :accession_number, unique: true
    add_index :filings, [ :company_id, :form_type, :filing_date ], unique: true
  end
end
