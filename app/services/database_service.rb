class DatabaseService
  def initialize(app_manifest, deploy)
    @app_manifest = app_manifest
    @deploy = deploy
  end

  def perform!
    unless @app_manifest['qafire'] && @app_manifest['qafire']['services'] && !@app_manifest['qafire']['services'].empty?
      puts 'No services'
      return
    end

    client = CloudFoundry.new
    current_db_service = client.find_service_instance(db_service_name)

    #TODO handle multiple services

    #TODO could refactor create_service so it works better with this service
    client.create_service(db_service_name,
                          @app_manifest['qafire']['services'][0]['type'],
                          @app_manifest['qafire']['services'][0]['plan'],
                          @deploy.full_name)

    DeployEventService.new(@deploy).service_created!

    unless current_db_service
      puts 'Skipping populating database - service already existed'
      DeployEventService.new(@deploy).service_already_exists!
      return
    end

    unless @app_manifest['qafire']['services'][0]['seed']
      puts 'no seed information in manifest'
      return
    end

    if @app_manifest['qafire']['services'][0]['seed']['s3']
      bucket = @app_manifest['qafire']['services'][0]['seed']['s3']['bucket']
      key = @app_manifest['qafire']['services'][0]['seed']['s3']['key']

      unless bucket && key
        puts 'Skipping seeding database - S3 bucket/key missing'
        return
      end

      s3_client = Aws::S3::Client.new(:credentials => aws_creds)
      Tempfile.open(['downloaded', '.sql']) do |file|
        puts "Downloading '#{key}' from S3..."
        s3_client.get_object(response_target: file.path, bucket: bucket, key: key)
        restore(client, file.path)
        puts 'Restore from s3 complete'
      end
    else
      puts 'manifest did not contain seed location'
    end
  end

  private

  def restore(client, path)
    if type.include?('postgres') || type.include?('pgsql')
      puts 'Running postgres restore...'
      unless system "psql #{database_url(client)} < #{path}"
        raise 'Postgres database restore failed'
      end
      unless system "psql #{database_url(client)} -c 'ANALYZE'"
        puts 'WARNING: Postgres analyze failed'
      end
    else
      raise "Type not supported: #{type}"
    end
  end

  def database_url(client)
    client.app_env(@deploy.full_name)[:system_env_json][:VCAP_SERVICES][type.to_s][0][:credentials][:uri]
  end

  def aws_creds
    Aws::Credentials.new(ENV['AWS_S3_ACCESS_KEY_ID'], ENV['AWS_S3_SECRET_ACCESS_KEY'])
  end

  def db_service_name
    "#{@deploy.full_name}-db"
  end

  def type
    @app_manifest['qafire']['services'][0]['type']
  end
end