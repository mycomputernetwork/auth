class CreateLogoutDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :logout_deliveries, id: :string do |t|
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :sid, null: false
      t.string :status, null: false
      t.string :detail
      t.datetime :created_at, null: false
    end

    add_index :logout_deliveries, %i[sid created_at]
  end
end
