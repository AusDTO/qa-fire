class AddPrToDeploys < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :pr, :integer
  end
end
