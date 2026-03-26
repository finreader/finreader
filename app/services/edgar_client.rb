require "net/http"
require "json"

class EdgarClient
  BASE_URL = "https://data.sec.gov"
  TICKERS_URL = "https://www.sec.gov/files/company_tickers.json"
  ARCHIVES_URL = "https://www.sec.gov/Archives/edgar/data"

  USER_AGENT = ENV.fetch("EDGAR_USER_AGENT", "Finreader admin@finreader.co")

  class EdgarError < StandardError; end
  class CompanyNotFound < EdgarError; end
  class FilingNotFound < EdgarError; end

  # Look up a company by ticker symbol. Returns { ticker:, name:, cik: }
  def self.search_company(ticker)
    response = get(TICKERS_URL)
    tickers = JSON.parse(response)

    ticker_up = ticker.strip.upcase
    match = tickers.values.find { |entry| entry["ticker"] == ticker_up }
    raise CompanyNotFound, "No company found for ticker '#{ticker}'" unless match

    {
      ticker: match["ticker"],
      name: match["title"],
      cik: match["cik_str"].to_s
    }
  end

  # Fetch filing submissions for a company by CIK. Returns parsed JSON.
  def self.fetch_submissions(cik)
    padded_cik = cik.to_s.rjust(10, "0")
    response = get("#{BASE_URL}/submissions/CIK#{padded_cik}.json")
    JSON.parse(response)
  end

  # Extract 10-K and 10-Q filing metadata from submissions data.
  # Returns array of hashes with keys: form_type, filing_date, accession_number, primary_document, period_of_report
  def self.extract_filings(submissions)
    recent = submissions["filings"]["recent"]
    forms = recent["form"]
    dates = recent["filingDate"]
    accessions = recent["accessionNumber"]
    documents = recent["primaryDocument"]
    periods = recent["reportDate"]

    filings = []
    forms.each_with_index do |form, i|
      next unless %w[10-K 10-Q].include?(form)

      filings << {
        form_type: form,
        filing_date: dates[i],
        accession_number: accessions[i],
        primary_document: documents[i],
        period_of_report: periods[i]
      }
    end

    filings
  end

  # Fetch the raw HTML of a specific filing document.
  def self.fetch_filing_html(cik, accession_number, primary_document)
    # SEC URLs use accession number without dashes in the path
    accession_path = accession_number.delete("-")
    url = "#{ARCHIVES_URL}/#{cik}/#{accession_path}/#{primary_document}"
    get(url)
  end

  private

  def self.get(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request["Accept-Encoding"] = "gzip, deflate"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess
      if response["content-encoding"] == "gzip"
        Zlib::GzipReader.new(StringIO.new(response.body)).read
      else
        response.body
      end
    when Net::HTTPNotFound
      raise FilingNotFound, "Resource not found: #{url}"
    else
      raise EdgarError, "SEC EDGAR request failed (#{response.code}): #{url}"
    end
  end
end
