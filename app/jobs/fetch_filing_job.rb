class FetchFilingJob < ApplicationJob
  queue_as :default

  def perform(filing_id)
    filing = Filing.find(filing_id)
    return if filing.parsed?

    EdgarSyncService.fetch_and_parse_filing(filing)
  end
end
