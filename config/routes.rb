require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations, :passwords ]

  authenticated :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  patch "session/edition", to: "sessions#update_edition", as: :update_edition_session

  namespace :webhooks do
    post "helloasso", to: "helloasso#create"
  end

  root to: "dashboard#index"

  resources :editions, only: [ :index, :new, :create, :edit, :update ]

  resources :workshops, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member do
      get :roster_pdf
    end
  end

  resources :participants, only: [ :index, :show ] do
    member do
      get :edit_workshops
      patch :update_workshops
      delete "registrations/:registration_id/workshop_override", action: :destroy_workshop_override, as: :registration_workshop_override
    end
  end

  resources :orders, only: [ :index, :show ]

  resources :staff_profiles do
    member do
      get :fiche
    end
    resources :staff_advances, only: [ :create, :destroy ]
    resources :staff_payments, only: [ :create, :destroy ]
  end

  scope :exports, as: :export, controller: :exports do
    get "/", action: :index, as: ""
    post "import-helloasso-csv", action: :import_helloasso_csv, as: :import_helloasso_csv
    get "participants", action: :participants, as: :participants
    get "workshop-roster", action: :workshop_roster_csv, as: :workshop_roster_csv
    get "staff-summary", action: :staff_summary, as: :staff_summary
    get "financial-report", action: :financial_report, as: :financial_report
    get "orders-csv", action: :orders_csv, as: :orders_csv
  end
end
