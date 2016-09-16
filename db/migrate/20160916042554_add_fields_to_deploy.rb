class AddFieldsToDeploy < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :trigger, :string
    add_column :deploys, :data, :json
  end
end
