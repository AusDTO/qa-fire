class ServerLaunchJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).launch!
    DeployEventService.new(deploy).server_launch_complete!
  rescue StandardError => err
    DeployEventService.new(deploy).unexpected_error!(err)
    raise
  end
end
