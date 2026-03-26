class FilingsController < ApplicationController
  def show
    @company = Company.find_by!(ticker: params[:company_ticker].upcase)

    # Parse slug like "2026-10-k" into year + form_type
    slug = params[:slug].to_s.downcase
    unless slug.match?(/\A\d{4}-10-[kq]\z/)
      redirect_to company_path(@company.ticker), alert: "Invalid filing format"
      return
    end

    year = slug[0..3].to_i
    form_type = slug[5..].upcase # "10-k" -> "10-K"

    @filing = @company.filings.find_by!(form_type: form_type, period_of_report: Date.new(year, 1, 1)..Date.new(year, 12, 31))

    # Fetch and parse the HTML if not already done
    unless @filing.parsed?
      EdgarSyncService.fetch_and_parse_filing(@filing)
      @filing.reload
    end

    @sections = @filing.sections
  rescue ActiveRecord::RecordNotFound
    redirect_to company_path(params[:company_ticker]), alert: "Filing not found"
  end
end
