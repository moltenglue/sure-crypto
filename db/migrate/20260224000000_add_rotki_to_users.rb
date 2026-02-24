class AddRotkiToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :rotki_encrypted_password, :string
  end
end
