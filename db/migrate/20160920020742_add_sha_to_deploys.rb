class AddShaToDeploys < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :sha, :string
  end
end
