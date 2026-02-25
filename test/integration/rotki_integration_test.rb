# frozen_string_literal: true

require "test_helper"

class RotkiIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @read_key = create_api_key(@user, scopes: %w[read])
    @read_write_key = create_api_key(@user, scopes: %w[read_write])
    @write_key = create_api_key(@user, scopes: %w[write])
  end

  test "full flow: connect and fetch balances" do
    RotkiService.any_instance.stubs(:create_user).returns({
      "result" => { "exchanges" => [], "settings" => {} },
      "message" => ""
    })

    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: api_key_headers(@read_write_key)

    assert_response :success

    Rotki::BalanceCache.any_instance.stubs(:get_balances).with(@user).returns({
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.0" }
      }
    })

    get "/api/v1/rotki/balances",
      headers: api_key_headers(@read_key)

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 8000.0, json["net_worth"]
    assert json["balances"]["total"]
    assert_equal 2, json["balances"]["total"].size
  end

  test "balances endpoint requires read scope - write-only key rejected" do
    get "/api/v1/rotki/balances",
      headers: api_key_headers(@write_key)

    assert_response :forbidden
  end

  test "connect endpoint requires write scope - read-only key rejected" do
    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: api_key_headers(@read_key)

    assert_response :forbidden
  end

  test "disconnect endpoint requires write scope" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")

    post "/api/v1/rotki/disconnect",
      headers: api_key_headers(@read_write_key)

    assert_response :success
    assert_nil @user.reload.rotki_username
  end

  private

    def create_api_key(user, scopes:)
      key_value = ApiKey.generate_secure_key
      api_key = ApiKey.create!(
        user: user,
        name: "Test API Key",
        scopes: scopes,
        source: "test",
        key: key_value
      )
      # Store plain key for headers
      api_key.instance_variable_set(:@plain_key, key_value)
      def api_key.plain_key; @plain_key; end
      api_key
    end

    def api_key_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end