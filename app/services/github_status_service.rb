class GithubStatusService
  def initialize(deploy, success)
    @deploy = deploy
    @success = success
  end

  # https://developer.github.com/v3/repos/statuses/
  def perform!
    if @deploy.user && @deploy.sha
      github = Octokit::Client.new(access_token: @deploy.user.github_token)
      info = {
          target_url: @deploy.decorate.url,
          description: message,
          context: 'QA Fire',
      }
      github.create_status(@deploy.repository, @deploy.sha, status, info)
    end
  end

  def message
    if @success
      'Your branch is now ready for testing'
    else
      'Deployment timed out'
    end
  end

  def status
    if @success
      'success'
    else
      'failure'
    end
  end
end
