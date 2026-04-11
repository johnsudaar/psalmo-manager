require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations, :passwords ]

  authenticated :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  patch "session/edition", to: "sessions#update_edition", as: :update_edition_session

  root to: "dashboard#index"
end
