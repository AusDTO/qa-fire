class Deploy < ApplicationRecord
  belongs_to :project

  store_accessor :data, :events
  store_accessor :data, :environment

  delegate :repository, :user, to: :project

  scope :by_manual, -> { where(trigger: 'manual').order(:name) }
  scope :by_github, -> { where(trigger: 'github').order(:name) }

  def full_name
    "#{name}-#{project.name}"
  end
end
