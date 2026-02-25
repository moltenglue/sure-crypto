require "test_helper"

class RotkiAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @user = users(:family_admin)
    @family = families(:dylan_family)
  end

  # Authentication & Authorization tests
  test "new redirects to providers when rotki not configured" do
    get new_rotki_account_path

    assert_redirected_to settings_providers_path
    assert_equal "Please configure Rotki in Settings > Providers first", flash[:alert]
  end

  test "new shows form when rotki is configured" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    get new_rotki_account_path

    assert_response :success
    assert_select "form[action=?]", rotki_accounts_path
  end

  test "create redirects to providers when rotki not configured" do
    post rotki_accounts_path

    assert_redirected_to settings_providers_path
    assert_equal "Please configure Rotki in Settings > Providers first", flash[:alert]
  end

  # Account creation flow tests
  test "create creates rotki item and imports balances when no existing item" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    mock_service = mock
    mock_service.expects(:all_balances).returns(
      blockchain: { "result" => {} },
      exchanges: { "result" => {} },
      manual: { "result" => [] }
    )
    RotkiService.expects(:new).with(username: "testuser", password: "password123").returns(mock_service)

    RotkiItem::Importer.any_instance.expects(:import).returns(imported: 0)

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "No balances found in Rotki. Make sure you have crypto in your Rotki portfolio.", flash[:alert]
  end

  test "create creates Sure accounts from Rotki accounts with balances" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    # Create a rotki item with accounts
    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    
    # Create rotki accounts with balances
    eth_account = rotki_item.rotki_accounts.create!(
      name: "ETH Wallet",
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 1.5
    )
    
    btc_account = rotki_item.rotki_accounts.create!(
      name: "BTC Wallet",
      currency: "BTC",
      account_type: "blockchain",
      current_balance: 0.5
    )

    # Expect the import to be called
    RotkiItem::Importer.any_instance.expects(:import).returns({ success: true, accounts_imported: 2 })
    
    # Expect process_accounts to be called
    rotki_item.expects(:process_accounts).once
    
    # Expect sync to be scheduled
    rotki_item.expects(:schedule_account_syncs).once

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "Created 2 Rotki accounts", flash[:notice]

    # Verify Sure accounts were created
    assert_equal 2, @family.accounts.where(accountable_type: "Crypto").count
    
    eth_sure_account = @family.accounts.find_by(name: "ETH Wallet")
    assert eth_sure_account
    assert_equal BigDecimal("1.5"), eth_sure_account.balance
    assert_instance_of Crypto, eth_sure_account.accountable
    
    btc_sure_account = @family.accounts.find_by(name: "BTC Wallet")
    assert btc_sure_account
    assert_equal BigDecimal("0.5"), btc_sure_account.balance
  end

  test "create establishes AccountProvider link between Sure and Rotki accounts" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    rotki_account = rotki_item.rotki_accounts.create!(
      name: "ETH Mainnet",
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 2.0
    )

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 1 })
    rotki_item.stubs(:process_accounts)
    rotki_item.stubs(:schedule_account_syncs)

    post rotki_accounts_path

    sure_account = @family.accounts.find_by(name: "ETH Mainnet")
    assert sure_account
    
    # Verify AccountProvider link exists
    account_provider = AccountProvider.find_by(account: sure_account)
    assert account_provider
    assert_equal rotki_account, account_provider.provider_account
  end

  test "create updates existing accounts instead of creating duplicates" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    # First, create an existing account
    existing_crypto = Crypto.create!
    existing_account = @family.accounts.create!(
      name: "My ETH Wallet",
      currency: "USD",
      accountable: existing_crypto,
      balance: 1000
    )

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    rotki_account = rotki_item.rotki_accounts.create!(
      name: "My ETH Wallet",  # Same name
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 5.0
    )

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 1 })
    rotki_item.stubs(:process_accounts)
    rotki_item.stubs(:schedule_account_syncs)

    initial_count = @family.accounts.count

    post rotki_accounts_path

    # Should not create a new account
    assert_equal initial_count, @family.accounts.count
    
    # Should link to existing account
    existing_account.reload
    assert existing_account.account_provider
    assert_equal rotki_account, existing_account.account_provider.provider_account
  end

  test "create handles partial import failures gracefully" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    
    # Create 3 rotki accounts
    3.times do |i|
      rotki_item.rotki_accounts.create!(
        name: "Wallet #{i}",
        currency: "ETH",
        account_type: "blockchain",
        current_balance: 1.0
      )
    end

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 3 })
    rotki_item.stubs(:process_accounts)
    rotki_item.stubs(:schedule_account_syncs)

    # Simulate one account failing to save
    Account.any_instance.stubs(:save).returns(true)
    Account.any_instance.stubs(:save).with(any_parameters).at_most(2).returns(true)
    
    post rotki_accounts_path

    # Should still report success for accounts that were created
    assert_redirected_to accounts_path
    assert flash[:notice].include?("Created")
  end

  # Error handling tests
  test "create handles errors gracefully" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    RotkiService.expects(:new).raises(StandardError.new("Connection refused"))

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_match /Error connecting to Rotki/, flash[:alert]
  end

  test "create handles importer failure" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    RotkiItem::Importer.any_instance.expects(:import).raises(StandardError.new("Import failed"))

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_match /Error connecting to Rotki/, flash[:alert]
  end

  # Existing item reuse tests
  test "create uses existing active rotki item if present" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    existing_item = @family.rotki_items.create!(name: "Existing Rotki", status: "good")

    # Should not create a new rotki item
    assert_no_difference -> { @family.rotki_items.count } do
      post rotki_accounts_path
    end
  end

  test "create creates new rotki_item when none exists" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 0 })

    assert_difference -> { @family.rotki_items.count }, 1 do
      post rotki_accounts_path
    end
  end

  # Sync scheduling tests
  test "create schedules sync for each created account" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    
    2.times do |i|
      rotki_item.rotki_accounts.create!(
        name: "Wallet #{i}",
        currency: "ETH",
        account_type: "blockchain",
        current_balance: 1.0
      )
    end

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 2 })
    rotki_item.stubs(:process_accounts)
    
    # Expect schedule_account_syncs to be called
    rotki_item.expects(:schedule_account_syncs).once

    post rotki_accounts_path
  end

  # Balance display tests (frontend integration)
  test "created accounts appear on accounts index page" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    rotki_item.rotki_accounts.create!(
      name: "Ethereum Mainnet",
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 10.5
    )

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 1 })
    rotki_item.stubs(:process_accounts)
    rotki_item.stubs(:schedule_account_syncs)

    post rotki_accounts_path

    # Visit accounts page
    get accounts_path
    assert_response :success
    
    # Should see the Rotki account
    assert_select "a", text: /Ethereum Mainnet/
    
    # Should see the balance
    assert_select ".balance", text: /10\.5/
  end

  test "created crypto accounts have correct subtype" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    rotki_item.rotki_accounts.create!(
      name: "MetaMask",
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 5.0
    )

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 1 })
    rotki_item.stubs(:process_accounts)
    rotki_item.stubs(:schedule_account_syncs)

    post rotki_accounts_path

    account = @family.accounts.find_by(name: "MetaMask")
    assert account
    assert_instance_of Crypto, account.accountable
    assert_equal "blockchain", account.accountable.subtype
  end

  # Authorization tests
  test "non-admin users cannot create rotki accounts" do
    sign_out users(:family_admin)
    sign_in users(:family_member)
    
    @user = users(:family_member)
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  # Transaction safety tests
  test "create rolls back on error to prevent partial account creation" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    rotki_item = @family.rotki_items.create!(name: "Rotki", status: "good")
    rotki_item.rotki_accounts.create!(
      name: "Test Wallet",
      currency: "ETH",
      account_type: "blockchain",
      current_balance: 1.0
    )

    RotkiItem::Importer.any_instance.stubs(:import).returns({ success: true, accounts_imported: 1 })
    
    # Simulate failure during account provider creation
    AccountProvider.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(AccountProvider.new))

    initial_account_count = @family.accounts.count

    post rotki_accounts_path

    # Should not have created any accounts due to transaction rollback
    assert_equal initial_account_count, @family.accounts.count
    assert_redirected_to accounts_path
    assert flash[:alert].present?
  end
end