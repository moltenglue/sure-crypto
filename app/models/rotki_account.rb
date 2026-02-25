class RotkiAccount < ApplicationRecord
  belongs_to :rotki_item
  has_one :family, through: :rotki_item
  has_one :account_provider, as: :provider, dependent: :destroy
  has_one :account, through: :account_provider

  validates :name, presence: true

  def current_account
    account
  end
end
