class GithubWebhookService
  def initialize(project, payload)
    @project = project
    @payload = payload
  end


  def perform!
    deploy = Deploy.find_or_create_by(remote_reference: @payload[:pull_request][:id])
    deploy.events ||= []
    deploy.project = @project
    deploy.trigger = 'github'
    deploy.branch = @payload[:pull_request]['head']['ref']
    deploy.sha = @payload[:pull_request]['head']['sha']
    deploy.pr = @payload[:number]
    deploy.name = "pr-#{@payload[:number]}"
    deploy.save

    return deploy
  end
end