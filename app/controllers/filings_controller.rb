class FilingsController < ApplicationController
  def show
    @company = Company.find_by!(ticker: params[:company_ticker].upcase)

    # Parse slug like "2024-01-31-10-k" into date + form_type
    slug = params[:slug].to_s.downcase
    unless slug.match?(/\A\d{4}-\d{2}-\d{2}-10-[kq]\z/)
      redirect_to company_path(@company.ticker), alert: "Invalid filing format"
      return
    end

    date_str = slug[0..9]     # "2024-01-31"
    form_type = slug[11..].upcase # "10-k" -> "10-K"

    @filing = @company.filings.find_by!(form_type: form_type, period_of_report: Date.parse(date_str))

    if @filing.completed?
      @sections = @filing.sections
    elsif @filing.pending?
      @filing.process!
      FetchFilingJob.perform_later(@filing.id)
      render :fetching
    else
      # processing or failed — just show the fetching/status page
      render :fetching
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to company_path(params[:company_ticker]), alert: "Filing not found"
  end
end
