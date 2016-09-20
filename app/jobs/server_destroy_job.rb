class ServerDestroyJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).destroy!
    project = deploy.project
    deploy.destroy

    if project.delete_flag && project.deploys.blank?
      project.destroy
    end
  end
end
