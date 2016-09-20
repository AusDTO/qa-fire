class DatabaseService
  def initialize app_manifest, app_name
    @app_name = app_name
    @app_manifest = app_manifest
  end

  def perform!
    unless s3_bucket && s3_key
      puts 'Skipping populating database - S3 bucket/key missing'
      return
    end

    s3 = Aws::S3::Client.new(:credentials => aws_creds)
    Tempfile.open(['downloaded', '.sql']) do |file|
      puts "Downloading '#{s3_key}' from S3..."
      s3.get_object(response_target: file.path, bucket: s3_bucket, key: s3_key)
      restore file.path
    end

    puts 'Restore complete'
  end

  private

  def restore path
    if type.include?('postgres') || type.include?('pgsql')
      puts 'Running postgres restore...'
      unless system "psql #{database_url} < #{path}"
        raise 'Postgres database restore failed'
      end
      unless system "psql #{database_url} -c 'ANALYZE'"
        puts 'WARNING: Postgres analyze failed'
      end
    else
      raise "Type not supported: #{type}"
    end
  end

  def database_url
    CloudFoundry.login
    CloudFoundry.get_env(@app_name)['system_env_json']['VCAP_SERVICES'][type][0]['credentials']['uri']
  end

  def aws_creds
    Aws::Credentials.new(ENV['AWS_S3_ACCESS_KEY_ID'], ENV['AWS_S3_SECRET_ACCESS_KEY'])
  end

  def s3_bucket
    @app_manifest["qafire"]["s3_bucket"]
  end

  def s3_key
    @app_manifest["qafire"]["s3_key"]
  end

  def type
    @app_manifest["qafire_services"][0]["type"]
  end
end