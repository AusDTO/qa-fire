class Project < ApplicationRecord
  has_many :deploys

  store_accessor :data, :environment

  validates :environment, json: true

  def name
    self.repository.split('/').reject(&:blank?).last
  end


  def environment_raw
    JSON.pretty_generate(self.environment)
  end


  def environment_raw=(value)
    self.environment = value
  end
end
