class Server
  # @param pr [Hash] the pull request Body hash
  # @see https://developer.github.com/v3/activity/events/types/#pullrequestevent
  def initialize(pr)
    #@pr_number = pr[:number]
    #@branch = pr[:head][:ref]
    #@repo_name = pr[:head][:repo][:full_name]
  end

  def launch!
    begin
      #TODO handle auth!
      cf_user = "admin"
      cf_password = "admin"
      cf_api = "http://api.local.pcfdev.io"
      cf_org = "pcfdev-org"
      cf_space = "pcfdev-space"
      #github_zip_url = "https://github.com/#{@repo_name}.git #{local_dir}"

      github_zip_url = "https://github.com/AusDTO/dto-sample-app/archive/master.zip"

      puts "Launching to #{target_url}"
      # FIXME: Definite santization problems here!
      # TODO: Use tmpdir
      puts "cf login -u #{cf_user} -p #{cf_password} -o #{cf_org} -s #{cf_space} -a #{cf_api}"

      Execute.go("cf login -u #{cf_user} -p #{cf_password} -o #{cf_org} -s #{cf_space} -a #{cf_api} --skip-ssl-validation")
      #TODO use /v2/info to find "authorization_endpoint":"https://login.local.pcfdev.io"
      #TODO use POST https://login.local.pcfdev.io/oauth/token with grant_type=password&password=[PRIVATE DATA HIDDEN]&scope=&username=admin
      # https://apidocs.cloudfoundry.org/241/apps/uploads_the_bits_for_an_app.html
      cf_space_guid = `cf space --guid #{cf_space}`.strip!
      oauth_token = `cf oauth-token`.strip!
      headers = {:Authorization => oauth_token}
      RestClient.proxy = "http://localhost:8888"

      result = RestClient.get("#{cf_api}/v2/spaces/#{cf_space_guid}/apps?q=name:#{app_name}&inline-relations-depth=1", headers)
      existing_apps = JSON.parse(result.body)
      if existing_apps["resources"].empty?
        result = RestClient.post("#{cf_api}/v2/apps",
                                 {name: app_name, space_guid: cf_space_guid, buildpack: 'staticfile_buildpack'}.to_json, headers)
        new_app = JSON.parse(result.body)
        cf_app_guid = new_app["metadata"]["guid"]
      else
        cf_app_guid = existing_apps['resources'][0]['metadata']['guid']
      end

      result = RestClient.get("#{cf_api}/v2/shared_domains", headers)
      shared_domains = JSON.parse(result.body)
      cf_domain_guid = shared_domains['resources'][0]['metadata']['guid']

      #check for existing routes
      result = RestClient.get("#{cf_api}/v2/routes?inline-relations-depth=1&q=host:#{app_name};domain_guid:#{cf_domain_guid}", headers)
      existing_routes = JSON.parse(result.body)
      if existing_routes["resources"].empty?
        #create a new route for app_name if none exist http://apidocs.cloudfoundry.org/241/routes/creating_a_route.html
        result = RestClient.post("#{cf_api}/v2/routes",
                                 {host: app_name, domain_guid: cf_domain_guid, space_guid: cf_space_guid}.to_json, headers)
        new_route = JSON.parse(result.body)
        cf_route_guid = new_route["metadata"]["guid"]
      else
        cf_route_guid = existing_routes['resources'][0]['metadata']['guid']
      end
      # associate route with app http://apidocs.cloudfoundry.org/241/apps/associate_route_with_the_app.html
      result = RestClient.put("#{cf_api}/v2/apps/#{cf_app_guid}/routes/#{cf_route_guid}",{}, headers)
      puts result

      # TODO check if files are already on cf push cache via PUT /v2/resource_match => [{"sha1":"0e0e99e7b065e1adea90072d300ba22cc5b17130","size":34}


      result = RestClient.put("#{cf_api}/v2/apps/#{cf_app_guid}/bits?async=true",
                               {:resources => [].to_json, :application => File.new("application.zip", 'rb')}, headers)
      push_job = JSON.parse(result.body)

      while push_job["entity"]["status"] == "queued"
        puts "waiting for push to complete"
        result = RestClient.get("#{cf_api}/v2/jobs/"+push_job["entity"]["guid"], headers)
        puts result
        push_job = JSON.parse(result.body)
      end

      #start app
      result = RestClient.put("#{cf_api}/v2/apps/#{cf_app_guid}?async=true",{state: "STARTED"}.to_json, headers)
      puts result

      #Execute.go("cf create-service dto-shared-pgsql shared-psql #{db_service_name}")
      #Execute.go("cf bind-service #{app_name} #{db_service_name}")
      set_envs
      Execute.go("cf start #{app_name}")
      Rails.logger.info("Done")
    rescue RestClient::ExceptionWithResponse => err
      puts err.response
      raise
    ensure
      FileUtils.remove_entry_secure(local_dir)
    end
  end

  def destroy!
    FileUtils.cd(local_dir) do
      Execute.go("cf stop #{app_name}")
      Execute.go("cf delete -f #{app_name}")
      Execute.go("cf delete-service -f #{db_service_name}")
    end
    FileUtils.remove_entry_secure(local_dir)
  end

  def local_dir
    "#{Rails.root}/tmp/#{app_name}-#{@branch}.zip"
  end

  def app_name
    "pr-#{@pr_number}"
  end

  def db_service_name
    "#{app_name}-db"
  end

  def base_url
    "apps.staging.digital.gov.au"
  end

  def target_url
    "#{app_name}.#{base_url}"
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
