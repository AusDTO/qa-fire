class Server
  def initialize(deploy)
    @deploy = deploy
    @branch = deploy.branch
    @repo_full_name = deploy.project.repository
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

      puts "Launching #{@deploy.full_name}"

      if CloudFoundry.login
        CloudFoundry.push(@deploy.full_name, app_manifest, app_zip)


        if app_manifest["qafire_services"] && app_manifest["qafire_services"][0]
          CloudFoundry.create_service(db_service_name,
                                      app_manifest["qafire_services"][0]["type"],
                                      app_manifest["qafire_services"][0]["plan"],
                                      @deploy.full_name)
        end

        #set_envs

        CloudFoundry.start_app(@deploy.full_name)

        puts 'Posting status to github'
        GithubStatusService.new(@deploy).perform!

        puts 'Done'
      end
    ensure
      FileUtils.remove_entry_secure(local_dir)
    end
  end

  def update!
    CloudFoundry.login
  end

  def destroy!
    CloudFoundry.login
    CloudFoundry.delete_app(@deploy.full_name)
    CloudFoundry.delete_service(db_service_name)
    @deploy.delete
  end

  def local_dir
    "#{Dir.tmpdir}/tmp/#{@deploy.full_name}"
  end

  def db_service_name
    "#{@deploy.full_name}-db"
  end
end
