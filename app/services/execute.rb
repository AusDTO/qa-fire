class Execute
  class ExecutionException < RuntimeError
    def initialize(command, exitstatus, stderr_out)
      @command    = command
      @exitstatus = exitstatus
      @stderr_out = stderr_out
    end

    def message
      <<-MSG
The command #{@command} failed to run with exit code #{@exitstatus}"
STDERR output:
#{@stderr_out}
      MSG
    end
  end

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
    unless status.exitstatus.to_i == 0
      raise ExecutionException.new(@command, status.exitstatus, stderr.read)
    end
  end

  def log(message)
    Rails.logger.info(message)
  end
end


