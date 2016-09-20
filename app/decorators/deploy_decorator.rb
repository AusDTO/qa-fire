class DeployDecorator < Draper::Decorator
  delegate_all

  def url
    "http://#{self.full_name}.#{Rails.configuration.deploy_base_url}"
  end
end