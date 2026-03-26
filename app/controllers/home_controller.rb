class HomeController < ApplicationController
  def index
  end

  def search
    @query = params[:query].to_s.strip
    if @query.blank?
      head :no_content
      return
    end

    begin
      company_data = EdgarClient.search_company(@query)
      @company = Company.find_or_initialize_by(cik: company_data[:cik])
      @company.assign_attributes(ticker: company_data[:ticker], name: company_data[:name])
      @company.save! if @company.new_record?
    rescue EdgarClient::CompanyNotFound
      @not_found = true
    rescue EdgarClient::EdgarError => e
      @error = e.message
    end

    render partial: "home/search_results", layout: false
  end
end
