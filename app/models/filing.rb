class Filing < ApplicationRecord
  belongs_to :company

  validates :form_type, presence: true, inclusion: { in: %w[10-K 10-Q] }
  validates :filing_date, presence: true
  validates :period_of_report, presence: true
  validates :accession_number, presence: true, uniqueness: true

  scope :annual, -> { where(form_type: "10-K") }
  scope :quarterly, -> { where(form_type: "10-Q") }
  scope :by_date, -> { order(filing_date: :desc) }

  def slug
    year = period_of_report.year
    form = form_type.downcase
    "#{year}-#{form}"
  end

  def parsed?
    parsed_sections.present? && parsed_sections["sections"].present?
  end

  def sections
    parsed_sections.fetch("sections", [])
  end
end
