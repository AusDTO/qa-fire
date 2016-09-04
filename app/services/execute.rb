class Execute
  def self.go(command)
    new(command).tap do |process|
      process.perform
    end
  end

  attr_reader :stdout, :stderr

  def initialize(command)
    @command = command
    log("Executing #{@command}")
  end

  def perform
    pid, stdin, @stdout, @stderr = Open4::popen4(@command)
    ignored, status = Process::waitpid2 pid
    if status.exitstatus.to_i == 0
      error = stderr.read
      log(error)
      raise "Failed with exit status #{status.exitstatus.to_i}"
    end
  end

  def log(message)
    Rails.logger.info(message)
  end
end


