class DeployService
  def initialize(deploy, action)
    @deploy = deploy
    @action = action
  end


  def perform!
    if deploy_action.keys.include? @action
      deploy_action[@action].perform_later(@deploy)
      DeployEventService.new(@deploy).async_task_enqueued!(@action)
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