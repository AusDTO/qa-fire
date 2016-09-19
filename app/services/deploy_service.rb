class DeployService
  def initialize(deploy, action)
    @deploy = deploy
    @action = action
  end


  def perform!
    if deploy_action.keys.include? @action
      deploy_action[@action].perform_later(@deploy)
    end
  end


  def deploy_action
    {
      'opened' => ServerLaunchJob,
      'reopened' => ServerLaunchJob,
      'synchronize' => ServerLaunchJob,
      'closed' => ServerDestroyJob
    }
  end
end