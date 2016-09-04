class ServerDestroyJob < ApplicationJob
  queue_as :default

  def perform(pr)
    Server.new(pr).destroy!
  end
end
