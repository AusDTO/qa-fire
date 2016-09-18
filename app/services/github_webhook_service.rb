class GithubWebhookService
  def initialize(project, payload)
    @project = project
    @payload = payload
  end


  def perform!
    deploy = Deploy.find_or_create_by(remote_reference: @payload[:pull_request][:id])
    deploy.data ||= []
    deploy.project = @project
    deploy.trigger = 'github'
    deploy.branch = @payload[:pull_request]['head']['ref']
    deploy.name = "pr-#{@payload[:number]}-#{deploy.project.name}"
    deploy.data += [WebhookPayloadFilterService.new(payload).filtered_hash]
    deploy.save
  end
end