Rails.application.routes.draw do
  root "home#index"

  # Ticker search (Turbo Frame)
  get "search", to: "home#search", as: :search

  resources :companies, only: [ :show ], param: :ticker do
    resources :filings, only: [ :show ], param: :slug
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
