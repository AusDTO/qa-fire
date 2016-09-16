class DeployService
  def initialize(deploy, action)
    @deploy = deploy
    @action = action
  end


  def perform!
    ServerLaunchJob.perform_later(@deploy) if %w(opened reopened).include?(@action)
    ServerDestroyJob.perform_later(@deploy) if @action == 'closed'
  end
end