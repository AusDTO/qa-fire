Rails.application.routes.draw do
  resource :github_webhooks, only: :create, defaults: { formats: :json }
  require 'sidekiq/web'
  mount Sidekiq::Web => '/queue'
end
