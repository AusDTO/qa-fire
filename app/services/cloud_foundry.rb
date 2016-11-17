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
    @space_guid = @client.spaces(q: "name:#{ENV['CF_SPACE']}").first_guid
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

  def push(app_name, app_manifest, app_zip)
    # create app if does not exist
    app_guid = get_app_guid(app_name)
    body = create_app_body(app_name, app_manifest, @space_guid)
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

  def stop_app(app_name)
    if app_guid = get_app_guid(app_name)
      @client.update_app(app_guid, {state: 'STOPPED'}, async: true)
      puts("stop complete for #{app_name}")
    end
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
      puts("delete complete for service #{service_name}")
    end
  end

  def get_env(app_name)
    if app_guid = get_app_guid(app_name)
      @client.app_env(app_guid)
    end
  end

  def get_app_logs(app_name)
    app_guid = get_app_guid(app_name)
    return unless app_guid
    @client.recent_logs(app_guid)
  end

  # creates body for https://apidocs.cloudfoundry.org/246/apps/creating_an_app.html
  def self.create_app_body(app_name, app_manifest, space_guid)
    #load values from manifest.yml including memory, buildpack and environment_json envvars
    app = {name: app_name, space_guid: space_guid}
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
    app.symbolize_keys
  end

  def self.normalize_size(app, entry)
    if app[entry]
      app[entry] = to_megabytes(app[entry])
    end
  end

  def self.to_megabytes(i)
    return (i =~ /\d+G/i) ? (i.to_i * 1024) : i.to_i
  end

  def self.qa_fire_override(app, app_manifest, entry)
    if app_manifest['qafire'][entry]
      app[entry] = app_manifest['qafire'][entry]
    end
  end

rescue RestClient::ExceptionWithResponse => err
  puts err.response
  raise
end
