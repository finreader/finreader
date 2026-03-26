class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :ticker, null: false
      t.string :name, null: false
      t.string :cik, null: false

      t.timestamps
    end
    add_index :companies, :ticker, unique: true
    add_index :companies, :cik, unique: true
  end
end
