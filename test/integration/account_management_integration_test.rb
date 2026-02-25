# frozen_string_literal: true

require "test_helper"

class AccountManagementIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    @family = families(:empty)
    sign_in(@user)
  end

  test "user can create a new account" do
    assert_difference("Account.count") do
      post accounts_path, params: {
        account: {
          name: "New Savings Account",
          accountable_type: "Depository",
          balance: 1000.00,
          currency_code: "USD"
        }
      }
    end
    assert_redirected_to accounts_path
  end

  test "user can view account details" do
    account = accounts(:empty_checking)
    get account_path(account)
    assert_response :success
  end

  test "user can update account" do
    account = accounts(:empty_checking)
    patch account_path(account), params: {
      account: {
        name: "Updated Account Name"
      }
    }
    assert_redirected_to accounts_path
    account.reload
    assert_equal "Updated Account Name", account.name
  end

  test "user can view accounts list" do
    get accounts_path
    assert_response :success
  end

  test "account creation requires valid data" do
    post accounts_path, params: {
      account: {
        name: "",
        accountable_type: ""
      }
    }
    assert_response :unprocessable_entity
  end

  test "user can sync account" do
    account = accounts(:empty_checking)
    post sync_account_path(account)
    assert_redirected_to account_path(account)
  end
end