require "test_helper"

class RotkiFullFlowIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    sign_in @user
  end

  test "full flow: connect to rotki, create account, and see balances" do
    RotkiService.any_instance.stubs(:login).returns({ "success" => true })

    post settings_rotki_connect_path, params: { rotki_username: "testuser", password: "password123" }

    assert_redirected_to settings_providers_path
    assert_equal "Connected to Rotki successfully", flash[:notice]

    @user.reload
    assert_equal "testuser", @user.rotki_username
    assert_equal "password123", @user.rotki_encrypted_password

    mock_service = mock
    mock_service.expects(:all_balances).returns(
      blockchain: { "result" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      exchanges: { "result" => {} },
      manual: { "result" => [] }
    )
    RotkiService.expects(:new).with(username: "testuser", password: "password123").returns(mock_service)

    RotkiItem::Importer.any_instance.stubs(:import).returns(imported: 1)

    post rotki_accounts_path

    assert_redirected_to accounts_path

    rotki_item = @family.rotki_items.last
    assert_not_nil rotki_item
    assert_equal 1, rotki_item.rotki_accounts.count

    account = Account.find_by(name: "ETH Wallet")
    assert_not_nil account
    assert_equal "Crypto", account.accountable_type
    assert_equal 1.5, account.balance
  end

  test "full flow: disconnecting removes credentials but keeps rotki item" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")
    @family.rotki_items.create!(name: "Rotki")

    post settings_rotki_disconnect_path

    assert_redirected_to settings_providers_path

    @user.reload
    assert_nil @user.rotki_username
    assert_nil @user.rotki_encrypted_password

    assert @family.rotki_items.exists?(name: "Rotki")
  end

  test "full flow: re-connecting updates credentials" do
    @user.update!(rotki_username: "olduser", rotki_encrypted_password: "oldpassword")

    RotkiService.any_instance.stubs(:login).returns({ "success" => true })

    post settings_rotki_connect_path, params: { rotki_username: "newuser", password: "newpassword" }

    @user.reload
    assert_equal "newuser", @user.rotki_username
    assert_equal "newpassword", @user.rotki_encrypted_password
  end

  test "full flow: account creation with multiple balances" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    mock_service = mock
    mock_service.expects(:all_balances).returns(
      blockchain: { "result" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" }, "BTC" => { "amount" => "0.5", "usd_value" => "25000.0" } } },
      exchanges: { "result" => { "binance" => { "total" => { "USDT" => { "amount" => "1000.0" } } } } },
      manual: { "result" => [ { "label" => "My Wallet", "amount" => "500.0", "currency" => "USD" } ] }
    )
    RotkiService.expects(:new).with(username: "testuser", password: "password123").returns(mock_service)

    RotkiItem::Importer.any_instance.stubs(:import).returns(imported: 4)

    rotki_item = @family.rotki_items.create!(name: "Rotki")
    rotki_item.rotki_accounts.create!(name: "ETH Wallet", currency: "ETH", account_type: "wallet", current_balance: 1.0)
    rotki_item.rotki_accounts.create!(name: "BTC Wallet", currency: "BTC", account_type: "wallet", current_balance: 0.5)
    rotki_item.rotki_accounts.create!(name: "Binance USDT", currency: "USDT", account_type: "exchange", current_balance: 1000.0)
    rotki_item.rotki_accounts.create!(name: "My Wallet", currency: "USD", account_type: "manual", current_balance: 500.0)

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "Created 4 Rotki accounts", flash[:notice]

    assert_equal 4, @family.accounts.where(accountable_type: "Crypto").count
  end

  test "full flow: error when no balances in rotki" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    mock_service = mock
    mock_service.expects(:all_balances).returns(
      blockchain: { "result" => {} },
      exchanges: { "result" => {} },
      manual: { "result" => [] }
    )
    RotkiService.expects(:new).with(username: "testuser", password: "password123").returns(mock_service)

    RotkiItem::Importer.any_instance.stubs(:import).returns(imported: 0)

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "No balances found in Rotki. Make sure you have crypto in your Rotki portfolio.", flash[:alert]
  end

  test "full flow: cannot create account without configuring rotki first" do
    get new_rotki_account_path

    assert_redirected_to settings_providers_path
    assert_equal "Please configure Rotki in Settings > Providers first", flash[:alert]
  end

  test "full flow: API returns balances when connected" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )

    access_token = Doorkeeper::AccessToken.create!(
      application: oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    mock_cache = mock
    mock_cache.expects(:get_balances).returns({
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.0" }
      }
    })

    Rotki::BalanceCache.any_instance.stubs(:get_balances).returns(
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.0" }
      }
    )

    get "/api/v1/rotki/balances", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 8000.0, json["net_worth"]
    assert_equal 2, json["balances"]["total"].size
  end
end
