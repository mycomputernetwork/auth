class CreateM1Tables < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :string do |t|
      t.string :google_sub
      t.string :email, null: false
      t.string :name
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :users, :google_sub, unique: true
    add_index :users, :email, unique: true

    create_table :sessions, id: :string do |t|
      t.references :user, null: false, type: :string, foreign_key: true
      t.string :sid, null: false
      t.string :user_agent
      t.string :ip_address
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :sessions, :sid, unique: true

    create_table :allowed_emails, id: :string do |t|
      t.string :email, null: false
      t.timestamps
    end
    add_index :allowed_emails, :email, unique: true
  end
end
