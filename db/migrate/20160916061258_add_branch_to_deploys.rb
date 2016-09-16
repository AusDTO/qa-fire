class AddBranchToDeploys < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :branch, :string
  end
end
