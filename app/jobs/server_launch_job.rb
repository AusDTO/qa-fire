class ServerLaunchJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).launch!
    DeployEventService.new(deploy).server_launch_complete!
  end
end
