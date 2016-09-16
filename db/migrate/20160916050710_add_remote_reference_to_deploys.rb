class AddRemoteReferenceToDeploys < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :remote_reference, :integer
  end
end
