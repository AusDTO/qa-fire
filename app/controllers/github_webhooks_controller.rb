class GithubWebhooksController < ApplicationController
  include GithubWebhook::Processor

  def create
  end

  def github_pull_request(payload)
    p payload
  end

  def webhook_secret(payload)
    #ENV['GITHUB_WEBHOOK_SECRET']
    '1234'
  end
end
