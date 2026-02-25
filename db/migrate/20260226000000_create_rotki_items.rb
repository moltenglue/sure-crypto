class CreateRotkiItems < ActiveRecord::Migration[7.2]
  def change
    create_table :rotki_items, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :name, default: "Rotki"
      t.string :status, default: "good"
      t.boolean :scheduled_for_deletion, default: false
      t.boolean :pending_account_setup, default: false
      t.jsonb :raw_payload
      t.timestamps
    end

    create_table :rotki_accounts, id: :uuid do |t|
      t.references :rotki_item, type: :uuid, null: false, foreign_key: true
      t.string :name
      t.string :currency
      t.decimal :current_balance, precision: 20, scale: 8, default: 0
      t.string :account_type
      t.string :provider, default: "rotki"
      t.jsonb :raw_payload
      t.jsonb :institution_metadata
      t.timestamps
    end
  end
end
