class Deploy < ApplicationRecord
  belongs_to :project
  has_many :deploy_events

  store_accessor :data, :events
  store_accessor :data, :environment

  validates :environment_raw, json: true
  validates :name, format: {with: /\A[\w-]+\Z/}, uniqueness: {scope: :project_id}
  validates :branch, format: {with: /\A\S+\Z/}

  delegate :repository, :user, to: :project

  scope :by_manual, -> { where(trigger: 'manual').order(:name) }
  scope :by_github, -> { where(trigger: 'github').order(:name) }


  def environment_raw
    @environment_raw || (environment && JSON.pretty_generate(environment))
  end


  def environment_raw=(value)
    @environment_raw = value

    if value.blank?
      self.environment = {}
    else
      begin
        self.environment = JSON.parse(@environment_raw)
      rescue JSON::ParserError
      end
    end
  end


  def full_name
    "#{name}-#{project.name}"
  end


  # Returns a merged hash from deploy, deploy.project and
  # QA-provided environment variables. To be used to provision
  # remote app instances
  def full_environment
    {
      QAFIRE_ENVIRONMENT: true
    }.merge(
      self.project.environment || {}
    ).merge(
      self.environment || {}
    )
  end
end
