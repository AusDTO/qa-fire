class DeployEventService
  def initialize(deploy, message=nil)
    @deploy = deploy
    @message = message
  end


  def perform!
    unless message.nil?
      save_event(@message)
    end
  end


  def webhook_received!
    save_event("A webhook was received for #{@deploy.full_name}")
  end


  def async_task_enqueued!(action)
    save_event("A remote action (#{action}) has been enqueued")
  end


  def server_launch_complete!
    save_event("A server was successfully launched")
  end


  def created_application_archive!
    save_event(
      "The target repository has been cloned and an application archive has been created"
    )
  end


  def application_pushed!
    save_event("The application has been pushed")
  end


  def service_created!
    save_event("A service has been created and bound to the application")
  end


  def service_already_exists!
    save_event("A service has been reused as it already existed")
  end

  private
  def save_event(message)
    DeployEvent.create(
      deploy: @deploy,
      timestamp: DateTime.now.utc,
      message: message
    )
  end
end