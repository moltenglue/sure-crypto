# frozen_string_literal: true

require "test_helper"

class Api::V1::RotkiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @read_key = create_api_key(@user, scopes: %w[read])
    @read_write_key = create_api_key(@user, scopes: %w[read_write])
  end

  test "should require authentication" do
    get "/api/v1/rotki/balances"
    assert_response :unauthorized
  end

  test "GET #balances requires read scope" do
    get "/api/v1/rotki/balances", headers: api_key_headers(@read_key)
    assert_response :success
  end

  test "GET #balances returns mapped balances" do
    Rotki::BalanceCache.any_instance.expects(:get_balances).with(@user).returns({
      "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }
    })

    get "/api/v1/rotki/balances", headers: api_key_headers(@read_key)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3000.0, json["net_worth"]
    assert_equal 1, json["balances"]["total"].length
  end

  test "GET #balances requires read scope - write key is rejected" do
    get "/api/v1/rotki/balances", headers: api_key_headers(@read_write_key)
    assert_response :forbidden
  end

  test "GET #balances handles service errors gracefully" do
    Rotki::BalanceCache.any_instance.expects(:get_balances).raises(StandardError, "Service unavailable")

    get "/api/v1/rotki/balances", headers: api_key_headers(@read_key)

    assert_response :internal_server_error
    json = JSON.parse(response.body)
    assert_equal "internal_error", json["error"]
  end

  test "POST #connect requires write scope" do
    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: api_key_headers(@read_write_key)

    assert_response :success
  end

  test "POST #connect authenticates with Rotki" do
    User.any_instance.expects(:authenticate_with_rotki!).with("test123").returns({ "success" => true })

    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: api_key_headers(@read_write_key)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "connected", json["status"]
  end

  test "POST #connect validates password presence" do
    post "/api/v1/rotki/connect",
      params: {},
      headers: api_key_headers(@read_write_key)

    assert_response :unprocessable_entity
  end

  test "POST #connect requires write scope - read key is rejected" do
    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: api_key_headers(@read_key)

    assert_response :forbidden
  end

  test "POST #connect handles authentication errors" do
    User.any_instance.expects(:authenticate_with_rotki!).raises(RotkiUserConcern::RotkiConnectionError, "Invalid credentials")

    post "/api/v1/rotki/connect",
      params: { password: "wrong123" },
      headers: api_key_headers(@read_write_key)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "connection_failed", json["error"]
  end

  test "POST #disconnect requires write scope" do
    User.any_instance.expects(:disconnect_rotki!).returns(true)

    post "/api/v1/rotki/disconnect",
      headers: api_key_headers(@read_write_key)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "disconnected", json["status"]
  end

  test "POST #disconnect requires write scope - read key is rejected" do
    post "/api/v1/rotki/disconnect",
      headers: api_key_headers(@read_key)

    assert_response :forbidden
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