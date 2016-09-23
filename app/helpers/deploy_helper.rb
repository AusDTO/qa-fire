module DeployHelper
  def time_since_timestamp(seconds)
    distance_of_time_in_words(DateTime.now.utc - seconds)
  end


  def time_since_timestamp_in_nanoseconds(nanoseconds)
    time_in_seconds = "#{nanoseconds}".to_f / 1000000000
    time_since_timestamp(DateTime.strptime("#{time_in_seconds}", '%s'))
  end
end