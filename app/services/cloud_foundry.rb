require 'log_events/uuid.pb.rb'
require 'log_events/metric.pb.rb'
require 'log_events/log.pb.rb'
require 'log_events/http.pb.rb'
require 'log_events/error.pb.rb'
require 'log_events/envelope.pb.rb'


class CloudFoundry
  def self.login
    # login
    cf_user = ENV['CF_USERNAME']
    cf_password = ENV['CF_PASSWORD']
    @cf_api = ENV['CF_API']
    cf_space = ENV['CF_SPACE']

    # RestClient.proxy = "http://10.0.1.181:8888"
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
                                                :headers => {:Authorization => "Basic Y2Y6",
                                                             # Basic Auth is username "cf" with no password
                                                             # like the cf-cli tool
                                                             params: {grant_type: "password", password: cf_password,
                                                                      scope: "", username: cf_user}
                                                },
                                                :verify_ssl => (authorization_endpoint == 'https://login.local.pcfdev.io' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER)
    )

    # TODO maintain refresh token using https://github.com/rest-client/rest-client#hook
    oauth_token = JSON.parse(authorization.body)["access_token"]
    @headers = {:Authorization => "bearer #{oauth_token}"}
    @space_guid = find_space(cf_space)['resources'][0]['metadata']['guid']
    puts("logged in to cf in space #{cf_space} (#{@space_guid})")
    true
  end

  def self.find_shared_domains
    result = RestClient.get("#{@cf_api}/v2/shared_domains", @headers)
    shared_domains = JSON.parse(result.body)
    shared_domains['resources']
  end

  def self.find_space(space_name)
    result = RestClient.get("#{@cf_api}/v2/spaces?q=name:#{space_name}", @headers)
    JSON.parse(result.body)
  end

  def self.find_service(service_name)
    result = RestClient.get("#{@cf_api}/v2/service_instances?q=name:#{service_name}", @headers)
    JSON.parse(result.body)
  end

  def self.find_first_service(service_name)
    find_service(service_name)['resources'][0]
  end

  def self.find_service_type(service_type_name)
    result = RestClient.get("#{@cf_api}/v2/services?q=label:#{service_type_name}", @headers)
    JSON.parse(result.body)
  end

  def self.find_service_plans(service_type_guid)
    result = RestClient.get("#{@cf_api}/v2/service_plans?q=service_guid:#{service_type_guid}", @headers)
    JSON.parse(result.body)
  end


  def self.create_service(service_name, service_type, service_plan, app_name)

    # create app if does not exist
    existing_services = find_service(service_name)
    if existing_services["resources"].empty?
      service_type = find_service_type(service_type)
      service_type_guid = service_type['resources'][0]['metadata']['guid']

      service_plans = find_service_plans(service_type_guid)
      #TODO find a particular service plan
      service_plan_guid = service_plans['resources'][0]['metadata']['guid']

      #TODO accepts_incomplete	Set to `true` if the client allows asynchronous provisioning. The cloud controller may respond before the service is ready for use.
      result = RestClient.post("#{@cf_api}/v2/service_instances",
                               {name: service_name, service_plan_guid: service_plan_guid, space_guid: @space_guid}.to_json, @headers)
      service = JSON.parse(result.body)
      service_guid = service['metadata']['guid']
      puts "created new service #{service_guid}"
    else
      puts "found existing service #{service_guid}"
      service_guid = existing_services['resources'][0]['metadata']['guid']
      #TODO update an service with envvars etc. http://apidocs.cloudfoundry.org/241/services/updating_an_service.html
    end

    existing_apps = find_app(app_name)
    app_guid = existing_apps['resources'][0]['metadata']['guid']
    begin
      result = RestClient.post("#{@cf_api}/v2/service_bindings",
                               {app_guid: app_guid, service_instance_guid: service_guid}.to_json, @headers)
      puts result
    rescue RestClient::ExceptionWithResponse => err
      if not JSON.parse(err.response)["error_code"] == "CF-ServiceBindingAppServiceTaken"
        raise
      end
    end
  end

  def self.find_app(app_name)
    result = RestClient.get("#{@cf_api}/v2/spaces/#{@space_guid}/apps?q=name:#{app_name}&inline-relations-depth=1", @headers)
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
      app = {name: app_name, space_guid: @space_guid}
      if app_manifest["applications"][0]
        app.merge!(app_manifest["applications"][0])
        if app["memory"]
          if app["memory"] =~ /\d+G/i
            app["memory"] = app["memory"].to_i * 1024
          else
            app["memory"] = app["memory"].to_i
          end
        end
        if app["disk_quota"]
          if app["disk_quota"] =~ /\d+G/i
            app["disk_quota"] = app["disk_quota"].to_i * 1024
          else
            app["disk_quota"] = app["disk_quota"].to_i
          end
        end
        app["name"] = app_name
      end
      if app_manifest["env"]
        app["environment_json"] = app_manifest["env"]
      end
      if app_manifest["qafire"]
        if app_manifest["qafire"]["command"]
          app["command"] = app_manifest["qafire"]["command"]
        end
        if app_manifest["qafire"]["buildpack"]
          app["buildpack"] = app_manifest["qafire"]["buildpack"]
        end
        if %w(none process).include? app_manifest["qafire"]["health_check_type"]
          app["health_check_type"] = "none"
        end
      end
      result = RestClient.post("#{@cf_api}/v2/apps",
                               app.to_json, @headers)
      new_app = JSON.parse(result.body)
      app_guid = new_app["metadata"]["guid"]
      puts "created new app #{app_guid}"
    else
      puts "found existing app #{app_guid}"
      app_guid = existing_apps['resources'][0]['metadata']['guid']
      #TODO update an app with envvars etc. http://apidocs.cloudfoundry.org/241/apps/updating_an_app.html
    end

    # find a domain name to use for app route
    cf_domain_guid = find_shared_domains.first['metadata']['guid']

    # check for existing routes for app
    result = RestClient.get("#{@cf_api}/v2/routes?inline-relations-depth=1&q=host:#{app_name};domain_guid:#{@cf_domain_guid}", @headers)
    existing_routes = JSON.parse(result.body)
    if existing_routes["resources"].empty?
      # create a new route for app_name if none exist http://apidocs.cloudfoundry.org/241/routes/creating_a_route.html
      result = RestClient.post("#{@cf_api}/v2/routes",
                               {host: app_name, domain_guid: cf_domain_guid, space_guid: @space_guid}.to_json, @headers)
      new_route = JSON.parse(result.body)
      cf_route_guid = new_route["metadata"]["guid"]
      puts "created new route #{cf_route_guid}"
    else
      cf_route_guid = existing_routes['resources'][0]['metadata']['guid']
      puts "found existing route #{cf_route_guid}"
    end

    # associate route with app http://apidocs.cloudfoundry.org/241/apps/associate_route_with_the_app.html
    result = RestClient.put("#{@cf_api}/v2/apps/#{app_guid}/routes/#{cf_route_guid}", {}, @headers)

    # TODO check if files are already on cf push cache via PUT /v2/resource_match => [{"sha1":"0e0e99e7b065e1adea90072d300ba22cc5b17130","size":34}
    # https://apidocs.cloudfoundry.org/241/apps/uploads_the_bits_for_an_app.html
    result = RestClient.put("#{@cf_api}/v2/apps/#{app_guid}/bits?async=true",
                            {:resources => [].to_json, :application => File.new(app_zip, 'rb')}, @headers)
    push_job = JSON.parse(result.body)

    while ['queued', 'running'].include?(push_job["entity"]["status"])
      puts("waiting for push to complete")
      sleep(1)
      result = RestClient.get("#{@cf_api}/v2/jobs/"+push_job["entity"]["guid"], @headers)
      push_job = JSON.parse(result.body)
    end
    puts("push complete for #{app_name}")
  end

  def self.start_app(app_name)
    #start app
    app = find_first_app(app_name)
    if app['entity']['state'] == 'STARTED'
      stop_app(app_name)
    end
    app_guid = app['metadata']['guid']
    result = RestClient.put("#{@cf_api}/v2/apps/#{app_guid}?async=true", {state: "STARTED"}.to_json, @headers)
    puts("start complete for #{app_name}")
  end

  def self.stop_app(app_name)
    #stop app
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      result = RestClient.put("#{@cf_api}/v2/apps/#{cf_app_guid}?async=true", {state: "STOPPED"}.to_json, @headers)
      puts("stop complete for #{app_name}")
    end
  end

  def self.delete_app(app_name)
    #delete app
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      result = RestClient.delete("#{@cf_api}/v2/apps/#{cf_app_guid}?async=tru&recursive=true", @headers)
      puts("delete complete for #{app_name}")
    end
  end

  def self.delete_service(service_name)
    #delete service
    if app = find_first_service(service_name)
      service_guid =app['metadata']['guid']
      result = RestClient.delete("#{@cf_api}/v2/service_instances/#{service_guid}?async=true", @headers)
      puts(result)
    end
  end

  def self.get_env(app_name)
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      result = RestClient.get("#{@cf_api}/v2/apps/#{cf_app_guid}/env", @headers)
      JSON.parse(result.body)
    end
  end


  def self.get_app_logs(app_name)
    if app = find_first_app(app_name)
      cf_app_guid = app['metadata']['guid']
      info = RestClient.get("#{@cf_api}/v2/info")
      logging_endpoint = JSON.parse(info.body)["doppler_logging_endpoint"].gsub('wss', 'https')

      resp = RestClient::Request.execute(
        url: "#{logging_endpoint}/apps/#{cf_app_guid}/recentlogs",
        headers: @headers,
        method: :get,
        verify_ssl: (logging_endpoint == 'https://doppler.local.pcfdev.io:443' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER),
        raw_response: true
      )

      boundary = resp.headers[:content_type].match(/(?<=boundary=).*/).to_s
      file = File.open(resp.file, 'rb')
      contents = file.read.split("--#{boundary}")

      contents[0..-2].each.inject([]) do |agg, item|
        unless item.blank?
          agg << Envelope.decode(Beefcake::Buffer.new(item[4..-3]))
        end

        agg
      end

    end
  end

rescue RestClient::ExceptionWithResponse => err
  puts err.response
  raise
end
