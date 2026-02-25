class AddRotkiUsernameToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :rotki_username, :string
  end
end
