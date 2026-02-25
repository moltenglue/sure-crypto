class AddStatusTextToSyncs < ActiveRecord::Migration[7.2]
  def change
    add_column :syncs, :status_text, :string
  end
end
