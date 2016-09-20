class GithubStatusService
  def initialize(deploy)
    @deploy = deploy
  end

  # https://developer.github.com/v3/repos/statuses/
  def perform!
    if @deploy.user
      github = Octokit::Client.new(access_token: @deploy.user.github_token)
      info = {
          target_url: @deploy.decorate.url,
          description: 'Your branch is now ready for testing',
          context: 'QA Fire',
      }
      github.create_status(@deploy.repository, @deploy.sha, 'success', info)
    end
  end
end