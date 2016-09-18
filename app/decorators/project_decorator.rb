class ProjectDecorator < Draper::Decorator
  decorates_association :deploys
  delegate_all
end