class Deploy < ApplicationRecord
  belongs_to :project

  store_accessor :data, :events
  store_accessor :data, :environment


  def full_name
    "#{name}-#{project.name}"
  end
end
