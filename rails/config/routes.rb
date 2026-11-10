Rails.application.routes.draw do
  root "sequences#index"

  resources :sequences, except: :show do
    member do
      get :run
      patch :move
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
