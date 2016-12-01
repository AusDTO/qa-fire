class ServerDestroyJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).destroy!
    project = deploy.project
    deploy.destroy

    if project.delete_flag && project.deploys.blank?
      project.destroy
    end
  rescue StandardError => err
    DeployEventService.new(deploy).unexpected_error!(err)
    raise
  end
end
