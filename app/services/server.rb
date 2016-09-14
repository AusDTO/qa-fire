class Server
  # @param pr [Hash] the pull request Body hash
  # @see https://developer.github.com/v3/activity/events/types/#pullrequestevent
  def initialize(pr)
    @pr_number = pr[:number]
    @branch = pr[:head][:ref]
    @repo_name = pr[:head][:repo][:full_name]
  end

  def launch!
    begin
      puts "cloning git and creating application archive"
      app_zip = "#{local_dir}/application.zip"
      app_manifest = {}
      # FIXME: Definite santization problems here!
      Execute.go("git clone https://github.com/#{@repo_name}.git #{local_dir} --depth 1")
      FileUtils.cd(local_dir) do
        Execute.go("git checkout #{@branch}")
        zf = ZipFileGenerator.new(local_dir, app_zip)
        zf.write()
        if File.exist?("manifest.yml")
          app_manifest = YAML.load_file("manifest.yml")
        end
      end
      puts "Launching #{@repo_name} #{@branch} (# #{@pr_number})"

      CloudFoundry.login
      CloudFoundry.push(app_name, app_manifest, app_zip)
      CloudFoundry.start(app_name)

      #Execute.go("cf create-service dto-shared-pgsql shared-psql #{db_service_name}")
      #Execute.go("cf bind-service #{app_name} #{db_service_name}")
      #set_envs

      Rails.logger.info("Done")
    ensure
      FileUtils.remove_entry_secure(local_dir)
    end
  end

  def destroy!
      CloudFoundry.login
      CloudFoundry.start(app_name)
      CloudFoundry.delete(app_name)
      #Execute.go("cf delete-service -f #{db_service_name}")
  end

  def local_dir
    "#{Dir.tmpdir}/tmp/#{app_name}"
  end

  def app_name
    "pr-#{@pr_number}"
  end

  def db_service_name
    "#{app_name}-db"
  end

  def set_envs
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
    ).each { |env| set_env(env) }
  end

  def set_env(env, value = ENV[env])
    # TODO: These data could later be stored in a DB to be more generic
    Execute.go("cf set-env #{app_name} #{env} #{value}")
  end
end
