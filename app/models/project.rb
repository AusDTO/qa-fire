class Project < ApplicationRecord
  has_many :deploys
  belongs_to :user

  store_accessor :data, :environment
  store_accessor :data, :delete_flag

  validates :environment_raw, json: true
  validates :repository, presence: true, uniqueness: true

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
