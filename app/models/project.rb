class Project < ApplicationRecord
  has_many :deploys

  store_accessor :data, :environment

  validates :environment_raw, json: true
  validates :repository, presence: true

  def name
    self.repository.split('/').reject(&:blank?).last
  end


  def environment_raw
    @environment_raw || (environment && JSON.pretty_generate(environment))
  end


  def environment_raw=(value)
    @environment_raw = value
    begin
      self.environment = JSON.parse(@environment_raw)
    rescue JSON::ParserError
    end
  end
end
