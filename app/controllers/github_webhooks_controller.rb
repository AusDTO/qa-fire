class GithubWebhooksController < ApplicationController
  include GithubWebhook::Processor

  def github_pull_request(payload)
    pr = payload[:pull_request]
    ServerLaunchJob.perform_later(pr) if %w(opened reopened).include?(payload[:action])
    ServerDestroyJob.perform_later(pr) if payload[:action] == 'closed'
  end

  def webhook_secret(payload)
    ENV['GITHUB_WEBHOOK_SECRET']
  end

  private
    def server(payload)
      Server.new(payload[:pull_request])
    end
end
