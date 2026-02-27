# frozen_string_literal: true

require "test_helper"

class AccountManagementIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    @family = families(:empty)
    sign_in(@user)
  end

  test "user can view account details" do
    account = accounts(:empty_checking)
    get account_path(account)
    assert_response :success
  end

  test "user can view accounts list" do
    get accounts_path
    assert_response :success
  end

  test "user can sync account" do
    account = accounts(:empty_checking)
    post sync_account_path(account)
    assert_response :redirect
  end
end
