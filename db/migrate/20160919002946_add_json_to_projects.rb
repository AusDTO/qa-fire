class AddJsonToProjects < ActiveRecord::Migration[5.0]
  def change
    add_column :projects, :data, :json
  end
end
