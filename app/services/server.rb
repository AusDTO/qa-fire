class Server
  # @param pr [Hash] the pull request Body hash
  # @see https://developer.github.com/v3/activity/events/types/#pullrequestevent
  def initialize(deploy)
    @deploy = deploy
    #@pr_number = pr[:number]
    @branch = deploy.branch#pr[:head][:ref]
    @repo_full_name = deploy.project.repository#pr[:head][:repo][:full_name]
    #@repo_name = pr[:head][:repo][:name]
  end

  def launch!
    begin
      puts "cloning git and creating application archive"
      app_zip = "#{local_dir}/application.zip"
      app_manifest = {application: [{}]}
      # FIXME: Definite santization problems here!
      Execute.go("git clone https://github.com/#{@repo_full_name}.git #{local_dir} --branch #{@branch} --depth 1 --single-branch")
      FileUtils.cd(local_dir) do
        zf = ZipFileGenerator.new(local_dir, app_zip)
        zf.write()
        if File.exist?("manifest.yml")
          app_manifest = YAML.load_file("manifest.yml")
        end
      end

      app_manifest["env"] = @deploy.environment

      puts "Launching #{@deploy.name}"

      if CloudFoundry.login
        CloudFoundry.push(@deploy.name, app_manifest, app_zip)


        if app_manifest["qafire_services"] && app_manifest["qafire_services"][0]
          CloudFoundry.create_service(db_service_name,
                                      app_manifest["qafire_services"][0]["type"],
                                      app_manifest["qafire_services"][0]["plan"],
                                      @deploy.name)
        end

        #set_envs

        CloudFoundry.start_app(@deploy.name)

        Rails.logger.info("Done")
      end
    ensure
      FileUtils.remove_entry_secure(local_dir)
    end
  end

  def destroy!
      CloudFoundry.login
      CloudFoundry.delete_app(@deploy.name)
      CloudFoundry.delete_service(db_service_name)
      #Execute.go("cf delete-service -f #{db_service_name}")
  end

  def local_dir
    "#{Dir.tmpdir}/tmp/#{@deploy.name}"
  end

  # def app_name
  #   "#{@repo_name}-pr-#{@pr_number}"
  # end

  def db_service_name
    "#{@deploy.name}-db"
  end
end
