module DeployHelper
  def time_since_timestamp(nanoseconds)
    time_in_seconds = "#{nanoseconds}".to_f / 1000000000
    distance_of_time_in_words(DateTime.now.utc - DateTime.strptime("#{time_in_seconds}", '%s'))
  end
end