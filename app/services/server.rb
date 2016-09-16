class Server
  # @param pr [Hash] the pull request Body hash
  # @see https://developer.github.com/v3/activity/events/types/#pullrequestevent
  def initialize(pr)
    @pr_number = pr[:number]
    @branch = pr[:head][:ref]
    @repo_full_name = pr[:head][:repo][:full_name]
    @repo_name = pr[:head][:repo][:name]
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
      app_manifest["env"] = {}
       %w(
        APP_DOMAIN
        AUTHORING_BASE_URL
        AWS_ACCESS_KEY
        AWS_SECRET_KEY
        CONTENT_ANALYSIS_BASE_URL
        FROM_EMAIL
        HTTP_PASSWORD
        HTTP_USERNAME
        SEED_USER_ADMIN_PASSWORD
        SEED_USER_PASSWORD
      ).each { |env| app_manifest["env"].merge!({env => ENV[env]}) if ENV[env] }
      puts "Launching #{@repo_full_name} #{@branch} (# #{@pr_number})"

      if CloudFoundry.login
        CloudFoundry.push(app_name, app_manifest, app_zip)


        if app_manifest["qafire_services"] && app_manifest["qafire_services"][0]
          CloudFoundry.create_service(db_service_name,
                                      app_manifest["qafire_services"][0]["type"],
                                      app_manifest["qafire_services"][0]["plan"],
                                      app_name)
        end

        #set_envs

        CloudFoundry.start_app(app_name)

        Rails.logger.info("Done")
      end
    ensure
      FileUtils.remove_entry_secure(local_dir)
    end
  end

  def destroy!
      CloudFoundry.login
      CloudFoundry.delete_app(app_name)
      CloudFoundry.delete_service(db_service_name)
      #Execute.go("cf delete-service -f #{db_service_name}")
  end

  def local_dir
    "#{Dir.tmpdir}/tmp/#{app_name}"
  end

  def app_name
    "#{@repo_name}-pr-#{@pr_number}"
  end

  def db_service_name
    "#{app_name}-db"
  end
end
