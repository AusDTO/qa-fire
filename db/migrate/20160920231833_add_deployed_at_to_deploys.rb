class AddDeployedAtToDeploys < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :deployed_at, :datetime
  end
end
