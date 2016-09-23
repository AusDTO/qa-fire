class CleanupDeploysJob < ApplicationJob
  queue_as :default

  def perform
    Project.find_each do |project|
      if project.user
        begin
          github = Octokit::Client.new(access_token: project.user.github_token)
          prs = github.pull_requests(project.repository, state: :open)
          pr_ids = prs.map(&:number)
          project.deploys.where(trigger: 'github').each do |deploy|
            ServerDestroyJob.perform_later(deploy) unless pr_ids.include?(deploy.pr)
          end
        rescue Octokit::Error => e
          puts e
        end
      end
    end
  end
end