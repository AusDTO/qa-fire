class CloudFoundry
  def self.login
    # login
    cf_user = ENV['CF_USERNAME']
    cf_password = ENV['CF_PASSWORD']
    @cf_api = ENV['CF_API']
    cf_space = ENV['CF_SPACE']

    # RestClient.proxy = "http://localhost:8888"
    #use /v2/info to find "authorization_endpoint":"https://login.local.pcfdev.io"
    begin
      info = RestClient.get("#{@cf_api}/v2/info")
    rescue RestClient::SSLCertificateNotVerified => e
      puts "ERROR SSL Certificate verify failed for #{@cf_api}/v2/info - if you are testing on pcfdev, ensure API URL is HTTP only"
      return false
    end

    authorization_endpoint = JSON.parse(info.body)["authorization_endpoint"]
    # ask for an oauth access/refresh token
    authorization = RestClient::Request.execute(:method => "post",
                                                :url => "#{authorization_endpoint}/oauth/token",
                                                :headers => {:Authorization => "Basic Y2Y6", # Basic Auth is username "cf" with no password like the cf-cli tool
                                                             params: {grant_type: "password", password: cf_password, scope: "", username: cf_user}
                                                },
                                                :verify_ssl => OpenSSL::SSL::VERIFY_NONE
    )

    # TODO maintain refresh token using https://github.com/rest-client/rest-client#hook
    oauth_token = JSON.parse(authorization.body)["access_token"]
    @headers = {:Authorization => "bearer #{oauth_token}"}
    @cf_space_guid = find_space(cf_space)['resources'][0]['metadata']['guid']
    puts("logged in to cf in space #{cf_space} (#{@cf_space_guid})")
    true
  end

  def self.find_space(space_name)
    result = RestClient.get("#{@cf_api}/v2/spaces?q=name:#{space_name}", @headers)
    JSON.parse(result.body)
  end

  def self.find_app(app_name)
    result = RestClient.get("#{@cf_api}/v2/spaces/#{@cf_space_guid}/apps?q=name:#{app_name}&inline-relations-depth=1", @headers)
    JSON.parse(result.body)
  end

  def self.find_first_app(app_name)
    find_app(app_name)['resources'][0]
  end

  def self.push(app_name, app_manifest, app_zip)
    #RestClient.proxy = "http://localhost:8888"

    # create app if does not exist
    existing_apps = find_app(app_name)
    if existing_apps["resources"].empty?
      #TODO load values from manifest.yml including memory, buildpack and environment_json envvars
      app = {name: app_name, space_guid: @cf_space_guid}
      if app_manifest["applications"][0]
        app.merge!(app_manifest["applications"][0])
        if app["memory"]
          app["memory"] = app["memory"].to_i
        end
        app["name"] = app_name
      end
      result = RestClient.post("#{@cf_api}/v2/apps",
                               app.to_json, @headers)
      new_app = JSON.parse(result.body)
      cf_app_guid = new_app["metadata"]["guid"]
      puts "created new app #{cf_app_guid}"
    else
      puts "found existing app #{cf_app_guid}"
      cf_app_guid = existing_apps['resources'][0]['metadata']['guid']
      #TODO update an app with envvars etc. http://apidocs.cloudfoundry.org/241/apps/updating_an_app.html
    end

    # find a domain name to use for app route
    result = RestClient.get("#{@cf_api}/v2/shared_domains", @headers)
    shared_domains = JSON.parse(result.body)
    cf_domain_guid = shared_domains['resources'][0]['metadata']['guid']

    # check for existing routes for app
    result = RestClient.get("#{@cf_api}/v2/routes?inline-relations-depth=1&q=host:#{app_name};domain_guid:#{@cf_domain_guid}", @headers)
    existing_routes = JSON.parse(result.body)
    if existing_routes["resources"].empty?
      # create a new route for app_name if none exist http://apidocs.cloudfoundry.org/241/routes/creating_a_route.html
      result = RestClient.post("#{@cf_api}/v2/routes",
                               {host: app_name, domain_guid: cf_domain_guid, space_guid: @cf_space_guid}.to_json, @headers)
      new_route = JSON.parse(result.body)
      cf_route_guid = new_route["metadata"]["guid"]
      puts "created new route #{cf_route_guid}"
    else
      cf_route_guid = existing_routes['resources'][0]['metadata']['guid']
      puts "found existing route #{cf_route_guid}"
    end

    # associate route with app http://apidocs.cloudfoundry.org/241/apps/associate_route_with_the_app.html
    result = RestClient.put("#{@cf_api}/v2/apps/#{cf_app_guid}/routes/#{cf_route_guid}", {}, @headers)

    # TODO check if files are already on cf push cache via PUT /v2/resource_match => [{"sha1":"0e0e99e7b065e1adea90072d300ba22cc5b17130","size":34}
    # https://apidocs.cloudfoundry.org/241/apps/uploads_the_bits_for_an_app.html
    result = RestClient.put("#{@cf_api}/v2/apps/#{cf_app_guid}/bits?async=true",
                            {:resources => [].to_json, :application => File.new(app_zip, 'rb')}, @headers)
    push_job = JSON.parse(result.body)

    while push_job["entity"]["status"] == "queued"
      puts("waiting for push to complete")
      sleep(1)
      result = RestClient.get("#{@cf_api}/v2/jobs/"+push_job["entity"]["guid"], @headers)
      push_job = JSON.parse(result.body)
    end
    puts("push complete for #{app_name}")
  end

  def self.start(app_name)
    #start app
    cf_app_guid =find_app(app_name)['resources'][0]['metadata']['guid']
    result = RestClient.put("#{@cf_api}/v2/apps/#{cf_app_guid}?async=true", {state: "STARTED"}.to_json, @headers)
    puts(result)
  end

  def self.stop(app_name)
    #stop app
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      result = RestClient.put("#{@cf_api}/v2/apps/#{cf_app_guid}?async=true", {state: "STOPPED"}.to_json, @headers)
      puts(result)
    end
  end

  def self.delete(app_name)
    #delete app
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      result = RestClient.delete("#{@cf_api}/v2/apps/#{cf_app_guid}?async=true", @headers)
      puts(result)
    end
  end

rescue RestClient::ExceptionWithResponse => err
  puts err.response
  raise
end