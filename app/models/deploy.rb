class Deploy < ApplicationRecord
  belongs_to :project

  store_accessor :data, :events
  store_accessor :data, :environment

  delegate :repository, :user, to: :project


  def full_name
    "#{name}-#{project.name}"
  end
end
