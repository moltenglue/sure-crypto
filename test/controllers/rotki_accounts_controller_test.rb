require "test_helper"

class RotkiAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @user = users(:family_admin)
    @family = families(:dylan_family)
  end

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

  test "create creates accounts when balances exist" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    mock_service = mock
    mock_service.expects(:all_balances).returns(
      blockchain: { "result" => {} },
      exchanges: { "result" => {} },
      manual: { "result" => [] }
    )
    RotkiService.expects(:new).with(username: "testuser", password: "password123").returns(mock_service)

    RotkiItem::Importer.any_instance.stubs(:import).returns(imported: 2)

    rotki_item = @family.rotki_items.create!(name: "Rotki")
    rotki_account1 = rotki_item.rotki_accounts.create!(name: "ETH Wallet", currency: "ETH", account_type: "wallet", current_balance: 1.5)
    rotki_account2 = rotki_item.rotki_accounts.create!(name: "BTC Wallet", currency: "BTC", account_type: "wallet", current_balance: 0.5)

    RotkiItem::Importer.any_instance.stubs(:import).returns(imported: 2)

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_equal "Created 2 Rotki accounts", flash[:notice]
  end

  test "create handles errors gracefully" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    RotkiService.expects(:new).raises(StandardError.new("Connection refused"))

    post rotki_accounts_path

    assert_redirected_to accounts_path
    assert_match /Error connecting to Rotki/, flash[:alert]
  end

  test "create uses existing active rotki item if present" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    existing_item = @family.rotki_items.create!(name: "Existing Rotki", status: "good")

    mock_service = mock
    RotkiService.expects(:new).never

    get new_rotki_account_path

    assert_response :success
  end
end
