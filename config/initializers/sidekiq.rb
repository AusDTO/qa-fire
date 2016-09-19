redis_url = ENV['REDIS_URL'] || nil
if ENV['VCAP_SERVICES'] && JSON.parse(ENV['VCAP_SERVICES'])["p-redis"]
  creds = JSON.parse(ENV['VCAP_SERVICES'])["p-redis"].first['credentials']
  redis_url = "redis://:#{creds['password']}@#{creds['host']}:#{creds['port']}/0"
end
redis_config = { url: redis_url, namespace: (ENV['REDIS_NAMESPACE'] || 'qa-fire') }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

Sidekiq.default_worker_options = { retry: 3 }