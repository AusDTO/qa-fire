class ServerDestroyJob < ApplicationJob
  queue_as :default

  def perform(deploy)
    Server.new(deploy).destroy!
  end
end
