class ServerLaunchJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).launch!
  end
end
