class Server
  def initialize(deploy)
    @deploy = deploy
    @branch = deploy.branch
    @repo_full_name = deploy.project.repository
  end

  def launch!
    Dir.mktmpdir do |local_dir|
      puts "cloning git and creating application archive"
      app_zip = "#{local_dir}/application.zip"
      app_manifest = {application: [{}]}
      FileUtils.cd(local_dir) do
        # FIXME: Definite santization problems here!
        Execute.go("git init")
        Execute.go("git pull https://#{@deploy.project.user.github_token.shellescape}@github.com/#{@repo_full_name.shellescape}.git #{@branch.shellescape} --depth 1")
        zf = ZipFileGenerator.new(local_dir, app_zip)
        zf.write()
        if File.exist?("manifest.yml")
          app_manifest = YAML.load_file("manifest.yml")
        end
      end

      DeployEventService.new(@deploy).created_application_archive!

      app_manifest["env"] = @deploy.full_environment

      if app_manifest['qafire'] && app_manifest['qafire']['self_deployed']
        puts "#{@deploy.full_name} is self deployed"
      else
        puts "Launching #{@deploy.full_name}"

        cf = CloudFoundry.new
        cf.push(@deploy.full_name, app_manifest, app_zip)
        DeployEventService.new(@deploy).application_pushed!

        DatabaseService.new(app_manifest, @deploy).perform!

        cf.start_app(@deploy.full_name)
      end

      deploy_success = cf.wait_for_deploy_status @deploy

      if @deploy.trigger == 'github'
        puts 'Posting status to github'
        GithubStatusService.new(@deploy, deploy_success).perform!
      end

      @deploy.update(deployed_at: DateTime.now)
      puts 'Done'
    end
  end

  def destroy!
    cf = CloudFoundry.new
    cf.delete_app(@deploy.full_name)
    cf.delete_service(db_service_name)
  end

  #TODO: DRY
  def db_service_name
    "#{@deploy.full_name}-db"
  end
end
