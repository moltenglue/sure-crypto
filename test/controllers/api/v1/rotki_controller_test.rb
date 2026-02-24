# frozen_string_literal: true

require "test_helper"

class Api::V1::RotkiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
  end

  test "should require authentication" do
    get "/api/v1/rotki/balances"
    assert_response :unauthorized
  end

  test "GET #balances returns mapped balances" do
    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    Rotki::BalanceCache.any_instance.expects(:get_balances).returns({
      "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }
    })

    get "/api/v1/rotki/balances", headers: {
      "Authorization" => "Bearer #{access_token.token}"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3000.0, json["net_worth"]
  end

  test "POST #connect authenticates with Rotki" do
    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    User.any_instance.expects(:authenticate_with_rotki!).with("password123")

    post "/api/v1/rotki/connect", params: { password: "password123" }, headers: {
      "Authorization" => "Bearer #{access_token.token}"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "connected", json["status"]
  end
end
