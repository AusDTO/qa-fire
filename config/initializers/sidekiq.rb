redis_config = { url: ENV['REDIS_URL'], namespace: (ENV['REDIS_NAMESPACE'] || 'qa-fire') }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

