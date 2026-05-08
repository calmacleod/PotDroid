Rails.application.routes.draw do
  mount Scalar::UI, at: "/api-docs"

  resource :session
  resources :passwords, param: :token
  resources :candidate_potholes, only: %i[ index show ] do
    member do
      patch :confirm
      patch :reject
      post :submit
    end
  end
  resources :api_tokens, only: %i[ create ]
  resources :pairing_sessions, only: %i[ create ]

  namespace :api do
    namespace :v1 do
      resources :candidate_potholes, only: %i[ create show ]
      resource :pairing, only: %i[ create ]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "candidate_potholes#index"
end
