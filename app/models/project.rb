class Project < ApplicationRecord
  has_many :deploys

  def name
    self.repository.split('/').reject(&:blank?).last
  end
end
