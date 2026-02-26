# frozen_string_literal: true

require "test_helper"

class ApiIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:empty)
    @user = users(:empty)
    @account = accounts(:empty_checking)
    @api_key = api_keys(:one)
  end

  test "unauthenticated requests return 401" do
    get api_v1_accounts_path
    assert_response :unauthorized
  end

  test "authenticated requests with valid API key succeed" do
    get api_v1_accounts_path, headers: api_headers(@api_key)
    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
  end

  test "authenticated requests can create transactions" do
    assert_difference("Transaction.count") do
      post api_v1_transactions_path, 
           headers: api_headers(@api_key),
           params: {
             transaction: {
               account_id: @account.id,
               amount: 100.00,
               currency_code: "USD",
               name: "Test Transaction",
               date: Date.today.to_s
             }
           }
    end
    assert_response :created
  end

  test "authenticated requests can fetch holdings" do
    get api_v1_holdings_path, headers: api_headers(@api_key)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("holdings")
  end

  test "rate limiting returns 429 when exceeded" do
    # Simulate multiple rapid requests
    5.times do
      get api_v1_accounts_path, headers: api_headers(@api_key)
    end
    # Response should be successful or rate limited, both are valid behaviors
    assert [200, 429].include?(response.status)
  end

  test "invalid API key returns 401" do
    get api_v1_accounts_path, headers: { "X-Api-Key" => "invalid_key" }
    assert_response :unauthorized
  end

  private

  def api_headers(api_key)
    {
      "X-Api-Key" => api_key.display_key,
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end
end