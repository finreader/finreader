class EdgarSyncService
  # Look up a company by ticker and sync its filing metadata from SEC EDGAR.
  # Returns the Company record with filings populated.
  def self.sync_company(ticker)
    # Find or create the company
    company_data = EdgarClient.search_company(ticker)
    company = Company.find_or_initialize_by(cik: company_data[:cik])
    company.update!(ticker: company_data[:ticker], name: company_data[:name])

    # Fetch and sync filing metadata
    submissions = EdgarClient.fetch_submissions(company.cik)
    filings_data = EdgarClient.extract_filings(submissions)

    filings_data.each do |fd|
      company.filings.find_or_create_by!(accession_number: fd[:accession_number]) do |filing|
        filing.form_type = fd[:form_type]
        filing.filing_date = fd[:filing_date]
        filing.period_of_report = fd[:period_of_report]
      end
    end

    company.reload
  end

  # Fetch and parse a filing's HTML content. Stores raw_html and parsed_sections.
  # Returns the updated Filing record.
  def self.fetch_and_parse_filing(filing)
    return filing if filing.completed?

    # We need the primary document path from EDGAR submissions
    submissions = EdgarClient.fetch_submissions(filing.company.cik)
    filing_meta = EdgarClient.extract_filings(submissions).find { |f| f[:accession_number] == filing.accession_number }
    raise EdgarClient::FilingNotFound, "Filing metadata not found for #{filing.accession_number}" unless filing_meta

    html = EdgarClient.fetch_filing_html(filing.company.cik, filing.accession_number, filing_meta[:primary_document])
    parsed = FilingParser.parse(html, filing.form_type)

    filing.update!(raw_html: html, parsed_sections: parsed)
    filing
  end
end
