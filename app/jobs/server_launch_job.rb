class ServerLaunchJob < ApplicationJob
  queue_as :default

  def perform(pr)
    Server.new(pr).launch!
  end
end
