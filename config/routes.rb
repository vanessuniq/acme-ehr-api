Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "rails/health#show"

  namespace :api do
    namespace :v1 do
      # Import endpoint
      post "import", to: "imports#create"

      # Records endpoints
      resources :records, only: [ :index, :show ]

      # Transform endpoint
      post "transform", to: "transforms#create"

      # Analytics endpoint
      get "analytics", to: "analytics#show"

      # Clinical timelines endpoint
      get "timelines", to: "timelines#index"
    end
  end
end
