class Deploy < ApplicationRecord
  belongs_to :project

  store_accessor :data, :events
  store_accessor :data, :environment

  validates :name, format: {with: /\A[\w-]+\Z/}
  validates :branch, format: {with: /\A\S+\Z/}

  delegate :repository, :user, to: :project

  scope :by_manual, -> { where(trigger: 'manual').order(:name) }
  scope :by_github, -> { where(trigger: 'github').order(:name) }

  def full_name
    "#{name}-#{project.name}"
  end
end
