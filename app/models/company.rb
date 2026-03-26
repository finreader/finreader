class Company < ApplicationRecord
  has_many :filings, dependent: :destroy

  validates :ticker, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :cik, presence: true, uniqueness: true

  normalizes :ticker, with: ->(ticker) { ticker.strip.upcase }
end
