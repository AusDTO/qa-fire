class DeployDecorator < Draper::Decorator
  delegate_all

  def url
    "http://#{self.name}.#{Rails.configuration.deploy_base_url}"
  end
end