class CompaniesController < ApplicationController
  def show
    @company = Company.find_by!(ticker: params[:ticker].upcase)

    # Sync filings from EDGAR if we have none yet
    if @company.filings.empty?
      EdgarSyncService.sync_company(@company.ticker)
      @company.reload
    end

    @annual_filings = @company.filings.annual.by_date
    @quarterly_filings = @company.filings.quarterly.by_date
  rescue ActiveRecord::RecordNotFound
    # Company not in our DB yet — try to sync from EDGAR
    begin
      @company = EdgarSyncService.sync_company(params[:ticker])
      @annual_filings = @company.filings.annual.by_date
      @quarterly_filings = @company.filings.quarterly.by_date
    rescue EdgarClient::CompanyNotFound
      redirect_to root_path, alert: "Company not found for ticker '#{params[:ticker]}'"
    end
  end
end
