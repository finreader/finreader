class AddStatusToFilings < ActiveRecord::Migration[8.1]
  def change
    add_column :filings, :status, :string, default: "pending", null: false
  end
end
