class GithubWebhookService
  def initialize(project, payload)
    @project = project
    @payload = payload
  end


  def perform!
    deploy = Deploy.find_or_create_by(remote_reference: @payload[:pull_request][:id])
    deploy.events ||= []
    deploy.project = @project
    deploy.environment = @project.environment
    deploy.trigger = 'github'
    deploy.branch = @payload[:pull_request]['head']['ref']
    deploy.sha = @payload[:pull_request]['head']['sha']
    deploy.name = "pr-#{@payload[:number]}"
    deploy.events += [WebhookPayloadFilterService.new(@payload).filtered_hash]
    deploy.save

    return deploy
  end
end