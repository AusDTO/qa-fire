require 'log_events/uuid.pb.rb'
require 'log_events/metric.pb.rb'
require 'log_events/log.pb.rb'
require 'log_events/http.pb.rb'
require 'log_events/error.pb.rb'
require 'log_events/envelope.pb.rb'


class CloudFoundry
  DEPLOY_STATUS_TIMEOUT = 15.minutes

  def initialize
    verify_ssl = !ENV['CF_API'].end_with?('local.pcfdev.io')
    @client = CfoundryClient.new(ENV['CF_API'], verify_ssl: verify_ssl)
    @client.login(ENV['CF_USERNAME'], ENV['CF_PASSWORD'])
    @space_guid = @client.spaces(q: "name:#{ENV['CF_SPACE']}").first[:metadata][:guid]
  end

  def get_app_logs(app_name)
    app_guid = get_app_guid(app_name)
    return unless app_guid
    @client.recent_logs(app_guid)
  end

  def get_app(app_name)
    @client.space_apps(@space_guid, q: "name:#{app_name}").first
  end

  def get_app_guid(app_name)
    @client.space_apps(@space_guid, q: "name:#{app_name}").first_guid
  end

  def get_service_instance(service_name)
    @client.service_instances(q: "name:#{service_name}").first_guid
  end

  def create_service(service_name, service_type, service_plan, app_name)
    # create service if does not exist
    service_instance_guid = get_service_instance(service_name)
    if service_instance_guid.nil?
      service_type_guid = @client.services(q: "label:#{service_type}").first_guid

      #TODO find a particular service plan
      service_plan_guid = @client.service_plans(q: "service_guid:#{service_type_guid}").first_guid

      #TODO accepts_incomplete	Set to `true` if the client allows asynchronous provisioning. The cloud controller may respond before the service is ready for use.
      service = @client.create_service_instance(service_name, service_plan_guid, @space_guid)

      service_instance_guid = service[:metadata][:guid]
      puts "created new service #{service_instance_guid}"
    else
      puts "found existing service #{service_instance_guid}"
      #TODO update an service with envvars etc. http://apidocs.cloudfoundry.org/241/services/updating_an_service.html
    end
    bind_service(service_name, app_name)
  end

  def bind_service(service_name, app_name)
    service_instance_guid = get_service_instance(service_name)
    app_guid = get_app_guid(app_name)
    begin
      @client.create_service_binding(service_instance_guid, app_guid)
    rescue RestClient::ExceptionWithResponse => err
      if not JSON.parse(err.response)["error_code"] == "CF-ServiceBindingAppServiceTaken"
        raise
      end
    end
  end

  def get_env(app_name)
    if app_guid = get_app_guid(app_name)
      @client.app_env(app_guid)
    end
  end

  # creates body for https://apidocs.cloudfoundry.org/246/apps/creating_an_app.html
  def create_app_body(app_name, app_manifest)
    #load values from manifest.yml including memory, buildpack and environment_json envvars
    app = {name: app_name, space_guid: @space_guid}
    if app_manifest['applications'][0]
      app.merge!(app_manifest['applications'][0])
      app['name'] = app_name
    end
    if app_manifest['env']
      app['environment_json'] = app_manifest['env']
    end
    if app_manifest['qafire']
      qa_fire_override(app, app_manifest, 'command')
      qa_fire_override(app, app_manifest, 'instances')
      qa_fire_override(app, app_manifest, 'buildpack')
      qa_fire_override(app, app_manifest, 'memory')
      qa_fire_override(app, app_manifest, 'disk_quota')
      if %w(none process).include? app_manifest['qafire']['health_check_type']
        app['health_check_type'] = 'none'
      end
      if app_manifest['qafire']['env'] # QA Fire specific env vars
        if app['environment_json']
          app['environment_json'].merge! app_manifest['qafire']['env']
        else
          app['environment_json'] = app_manifest['qafire']['env']
        end
      end
    end
    normalize_size(app, 'memory')
    normalize_size(app, 'disk_quota')
    app
  end

  def normalize_size(app, entry)
    if app[entry]
      app[entry] = to_megabytes(app[entry])
    end
  end

  def qa_fire_override(app, app_manifest, entry)
    if app_manifest['qafire'][entry]
      app[entry] = app_manifest['qafire'][entry]
    end
  end

  def to_megabytes(i)
    return (i =~ /\d+G/i) ? (i.to_i * 1024) : i.to_i
  end

  def push(app_name, app_manifest, app_zip)
    # create app if does not exist
    app_guid = get_app_guid(app_name)
    body = create_app_body(app_name, app_manifest)
    begin
      if app_guid.nil?
        new_app = @client.create_app(body)
        app_guid = new_app[:metadata][:guid]
        puts "created new app #{app_guid}"
      else
        puts "found existing app #{app_guid}"
        @client.update_app(app_guid, body)
      end
    rescue RestClient::ExceptionWithResponse => err
      puts err.response
      raise
    end

    # find a domain name to use for app route
    domain_guid = @client.shared_domains.first_guid

    # check for existing routes for app
    route_guid = @client.routes(q: "host:#{app_name};domain_guid:#{domain_guid}").first_guid
    if route_guid.nil?
      route_guid = @client.create_route(domain_guid, @space_guid, host: app_name)[:metadata][:guid]
      puts "created new route #{route_guid}"
    else
      puts "found existing route #{route_guid}"
    end
    @client.create_app_route(app_guid, route_guid)

    # TODO check if files are already on cf push cache via PUT /v2/resource_match => [{"sha1":"0e0e99e7b065e1adea90072d300ba22cc5b17130","size":34}
    push_job = @client.update_app_bits(app_guid, [], File.new(app_zip, 'rb'), async: true)

    while %w{queued running}.include?(push_job[:entity][:status])
      puts("waiting for push to complete")
      sleep(1)
      push_job = @client.job(push_job[:metadata][:guid])
    end
    puts("push complete for #{app_name}")
  end

  def start_app(app_name)
    app = get_app(app_name)
    if app[:entity][:state] == 'STARTED'
      stop_app(app_name)
    end
    app_guid = app[:metadata][:guid]

    @client.update_app(app_guid, {state: 'STARTED'}, async: true)
    puts("start complete for #{app_name}")
  end

  def stop_app(app_name)
    if app_guid = get_app_guid(app_name)
      @client.update_app(app_guid, {state: 'STOPPED'}, async: true)
      puts("stop complete for #{app_name}")
    end
  end

  def wait_for_deploy_status(deploy)
    start = Time.now.to_i
    host = "#{deploy.full_name}.#{Rails.configuration.deploy_base_url}"

    while Time.now.to_i - start < DEPLOY_STATUS_TIMEOUT
      code = Net::HTTP.start(host, 80) {|http| http.head('/').code }

      if [200, 301].include? code.to_i # 301 if site redirects e.g. for https
        puts "Server responded with #{code}, continuing"
        return true
      end

      puts "Server responded with #{code}, waiting..."
      sleep 10
    end

    puts "Server deploy timed out :("
    false
  end

  def delete_app(app_name)
    if app_guid = get_app_guid(app_name)
      @client.delete_app(app_guid, async: true, recursive: true)
      puts("delete complete for #{app_name}")
    end
  end

  def delete_service(service_name)
    if service_guid = get_service_instance(service_name)
      @client.delete_service_instance(service_guid, async: true, recursive: true)
    end
  end

  ######################
  ### OLD STATIC WAY ###
  ######################

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

  def self.to_megabytes(i)
    return (i =~ /\d+G/i) ? (i.to_i * 1024) : i.to_i
  end

  def self.generate_app(app_name, app_manifest)
    #load values from manifest.yml including memory, buildpack and environment_json envvars
    app = {name: app_name, space_guid: @space_guid}
    if app_manifest["applications"][0]
      app.merge!(app_manifest["applications"][0])
      if app["memory"]
        app["memory"] = to_megabytes(app["memory"])
      end
      if app["disk_quota"]
        app["disk_quota"] = to_megabytes(app["disk_quota"])
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
      if app_manifest["qafire"]["instances"]
        app["instances"] = app_manifest["qafire"]["instances"]
      end
      if app_manifest["qafire"]["buildpack"]
        app["buildpack"] = app_manifest["qafire"]["buildpack"]
      end

      if app_manifest["qafire"]["memory"]
        app["memory"] = to_megabytes(app_manifest["qafire"]["memory"])
      end

      if app_manifest["qafire"]["disk_quota"]
        app["disk_quota"] = to_megabytes(app_manifest["qafire"]["disk_quota"])
      end

      if %w(none process).include? app_manifest["qafire"]["health_check_type"]
        app["health_check_type"] = "none"
      end
      if app_manifest["qafire"]["env"] # QA Fire specific env vars
        if app["environment_json"]
          app["environment_json"].merge! app_manifest["qafire"]["env"]
        else
          app["environment_json"] = app_manifest["qafire"]["env"]
        end
      end
    end
    app
  end

  def self.push(app_name, app_manifest, app_zip)


    # create app if does not exist
    existing_apps = find_app(app_name)
    app = self.generate_app(app_name, app_manifest)
    begin
      if existing_apps["resources"].empty?
        result = RestClient.post("#{@cf_api}/v2/apps",
                                 app.to_json, @headers)
        new_app = JSON.parse(result.body)
        app_guid = new_app["metadata"]["guid"]
        puts "created new app #{app_guid}"
      else
        puts "found existing app #{app_guid}"
        app_guid = existing_apps['resources'][0]['metadata']['guid']
        #update an app with envvars etc. http://apidocs.cloudfoundry.org/241/apps/updating_an_app.html
        #RestClient.proxy = "http://localhost:8888"
        RestClient.put("#{@cf_api}/v2/apps/#{app_guid}", app.to_json, @headers)
      end
    rescue RestClient::ExceptionWithResponse => err
      puts err.response
      raise
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

    result = RestClient.put("#{@cf_api}/v2/apps/#{app_guid}?async=true", { state: 'STARTED' }.to_json, @headers)
    puts("start complete for #{app_name}")
  end

  def self.wait_for_deploy_status(deploy)
    start = Time.now.to_i
    host = "#{deploy.full_name}.#{Rails.configuration.deploy_base_url}"

    while Time.now.to_i - start < DEPLOY_STATUS_TIMEOUT
      code = Net::HTTP.start(host, 80) {|http| http.head('/').code }

      if [200, 301].include? code.to_i # 301 if site redirects e.g. for https
        puts "Server responded with #{code}, continuing"
        return true
      end

      puts "Server responded with #{code}, waiting..."
      sleep 10
    end

    puts "Server deploy timed out :("
    false
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
