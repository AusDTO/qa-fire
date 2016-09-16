Rails.application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }
  devise_scope :user do
    get 'users/sign_in', :to => 'devise/sessions#new', :as => :new_user_session
    delete 'users/sign_out', :to => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  resource :github_webhooks, only: :create, defaults: { formats: :json }
  require 'sidekiq/web'
  mount Sidekiq::Web => '/queue'

  root to: 'projects#index'
  resources :projects, path: '/' do
    resources :deploys
  end
end
