require "test_helper"

class RotkiAccountTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @rotki_item = @family.rotki_items.create!(name: "My Rotki")
  end

  test "creates rotki account with required fields" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    assert_not_nil rotki_account
    assert_equal "ETH Wallet", rotki_account.name
    assert_equal "ETH", rotki_account.currency
    assert_equal "wallet", rotki_account.account_type
    assert_equal "rotki", rotki_account.provider
  end

  test "validates presence of name" do
    rotki_account = @rotki_item.rotki_accounts.build(name: nil)
    refute rotki_account.valid?
    assert rotki_account.errors[:name].present?
  end

  test "belongs to rotki item" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    assert_equal @rotki_item, rotki_account.rotki_item
  end

  test "has one family through rotki item" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    assert_equal @family, rotki_account.family
  end

  test "has one account provider" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    account_provider = AccountProvider.create!(
      provider_account: rotki_account,
      provider: "rotki"
    )

    assert_equal account_provider, rotki_account.account_provider
  end

  test "has one account through account provider" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    account_provider = AccountProvider.create!(
      provider_account: rotki_account,
      provider: "rotki"
    )

    account = @family.accounts.create!(
      name: "Crypto Account",
      accountable: Crypto.new(subtype: "ETH"),
      account_provider: account_provider
    )

    assert_equal account, rotki_account.account
  end

  test "current_account returns the associated account" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    account_provider = AccountProvider.create!(
      provider_account: rotki_account,
      provider: "rotki"
    )

    account = @family.accounts.create!(
      name: "Crypto Account",
      accountable: Crypto.new(subtype: "ETH"),
      account_provider: account_provider
    )

    assert_equal account, rotki_account.current_account
  end

  test "has default provider of rotki" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    assert_equal "rotki", rotki_account.provider
  end

  test "can store raw payload" do
    payload = { "address" => "0x1234", "balance" => "1.5" }
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet",
      raw_payload: payload
    )

    assert_equal payload, rotki_account.raw_payload
  end

  test "can store institution metadata" do
    metadata = { "institution_name" => "Coinbase", "institution_id" => "coinbase_123" }
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet",
      institution_metadata: metadata
    )

    assert_equal metadata, rotki_account.institution_metadata
  end

  test "can store current balance" do
    rotki_account = @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet",
      current_balance: 1.5
    )

    assert_equal 1.5, rotki_account.current_balance
  end

  test "destroying rotki item destroys rotki accounts" do
    @rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "wallet"
    )

    assert_difference "RotkiAccount.count", -1 do
      @rotki_item.destroy
    end
  end
end
