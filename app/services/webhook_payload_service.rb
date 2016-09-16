class WebhookPayloadService
  def initialize(payload)
    @payload = payload
  end


  def filtered_hash
    hash_filter(@payload)
  end


  private
  def hash_filter(hash)
    hash.keys.inject({}) do |agg, key|
      if hash[key].class == Hash
        agg[key] = hash_filter(hash[key])
      else
        if key.to_s.match(/^.*(?<!url)$/)
          agg[key] = hash[key]
        end
      end

      agg
    end
  end
end