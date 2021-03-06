require 'exceptions'

class GithubWebhooksController < ApplicationController
  include GithubWebhook::Processor

  unless Rails.env.production?
    skip_before_action :authenticate_github_request!, only: :create
  end

  rescue_from Exceptions::InvalidProjectError, with: :not_found

  def github_pull_request(payload)
    # Check Projects
    project = get_project(payload)

    if project.nil?
      raise Exceptions::InvalidProjectError.new('Project not found')
    else
      deploy = GithubWebhookService.new(project, payload).perform!
      DeployEventService.new(deploy).webhook_received!
      DeployService.new(deploy, payload[:action]).perform!
    end
  end

  def webhook_secret(payload)
    project = get_project(payload)
    unless project.nil?
      return project.webhook_secret
    end

    return ''
  end

  private

  def get_project(payload)
    if payload.keys.include?('repository') && payload[:repository].keys.include?('full_name')
      Project.find_by(repository: payload[:repository][:full_name])
    else
      return nil
    end
  end

  def not_found
    render json: { error: 'Project not found'}.to_json, status: 404 and return
  end
end
