class CleanupDeploysJob < ApplicationJob
  queue_as :default

  def perform
    # Login
    CloudFoundry.login

    # Ensure Deploy objects exist in cf
    delete_ids = Deploy.all.inject([]) do |agg, deploy|
      if CloudFoundry.find_app(deploy.name)['total_results'] == 0
        agg << deploy
      end

      agg
    end

    # Delete where they don't exist anymore
    unless delete_ids.empty?
      Deploy.where(id: delete_ids).delete_all
    end
  end
end