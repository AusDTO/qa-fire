class CreateProjects < ActiveRecord::Migration[5.0]
  def change
    create_table :projects do |t|
      t.string :repository
      t.string :webhook_secret

      t.timestamps
    end
  end
end
