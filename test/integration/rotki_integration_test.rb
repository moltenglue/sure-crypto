# frozen_string_literal: true

require "test_helper"

class RotkiIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
  end

  test "full flow: connect and fetch balances" do
    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    RotkiService.any_instance.stubs(:create_user).returns({
      "result" => { "exchanges" => [], "settings" => {} },
      "message" => ""
    })

    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success

    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    Rotki::BalanceCache.any_instance.stubs(:get_balances).returns({
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.0" }
      }
    })

    get "/api/v1/rotki/balances",
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 8000.0, json["net_worth"]
    assert json["balances"]["total"]
    assert_equal 2, json["balances"]["total"].size
  end

  test "balances endpoint requires read scope" do
    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "write"
    )

    get "/api/v1/rotki/balances",
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "connect endpoint requires write scope" do
    access_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    post "/api/v1/rotki/connect",
      params: { password: "test123" },
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end
end
