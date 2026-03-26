class FetchFilingJob < ApplicationJob
  queue_as :default

  def perform(filing_id)
    filing = Filing.find(filing_id)
    return unless filing.processing?

    EdgarSyncService.fetch_and_parse_filing(filing)
    filing.complete!
  rescue => e
    filing&.fail! if filing&.may_fail?
    raise
  end
end
