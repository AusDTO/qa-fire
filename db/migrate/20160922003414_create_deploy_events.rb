class CreateDeployEvents < ActiveRecord::Migration[5.0]
  def change
    create_table :deploy_events do |t|
      t.datetime :timestamp
      t.string :message
      t.references :deploy, foreign_key: {on_delete: :cascade}
      t.timestamps
    end
  end
end
