require "test_helper"

class RotkiServiceTest < ActiveSupport::TestCase
  setup do
    @service = RotkiService.new
  end

  test "creates user in Rotki" do
    stub_rotki_api(:post, "/api/1/users", { "result" => { "exchanges" => [], "settings" => {} }, "message" => "" })
    
    result = @service.create_user("testuser", "password123")
    
    assert_equal ["exchanges", "settings"], result.keys
  end

  test "authenticates against Rotki" do
    stub_rotki_api(:post, "/api/1/users/testuser", { "result" => { "exchanges" => [], "settings" => {} }, "message" => "" })
    
    result = @service.login("testuser", "password123")
    
    assert_equal ["exchanges", "settings"], result.keys
  end

  test "fetches all balances" do
    stub_rotki_api(:get, "/api/1/balances", { "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } }, "message" => "" })
    
    result = @service.balances
    
    assert_equal "1.0", result.dig("result", "total", "ETH", "amount")
  end

  test "logs out user from Rotki" do
    stub_rotki_api(:patch, "/api/1/users/testuser", { "result" => true, "message" => "" })
    
    result = @service.logout("testuser")
    
    assert_equal true, result["result"]
  end

  test "fetches blockchain balances" do
    stub_rotki_api(:get, "/api/1/balances/blockchain", { "result" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }, "message" => "" })
    
    result = @service.blockchain_balances
    
    assert_equal "1.0", result["result"]["ETH"]["amount"]
  end

  test "fetches exchange balances" do
    stub_rotki_api(:get, "/api/1/balances/exchanges", { "result" => { "binance" => { "total" => { "BTC" => { "amount" => "0.5" } } } }, "message" => "" })
    
    result = @service.exchange_balances
    
    assert_equal "0.5", result["result"]["binance"]["total"]["BTC"]["amount"]
  end

  test "fetches manual balances" do
    stub_rotki_api(:get, "/api/1/balances/manual", { "result" => [{ "label" => "My Wallet", "amount" => "1000", "currency" => "USD" }], "message" => "" })
    
    result = @service.manual_balances
    
    assert_equal 1, result["result"].size
  end

  test "fetches periodic data" do
    stub_rotki_api(:get, "/api/1/periodic", { "result" => { "last_balance_save" => 1234567890 }, "message" => "" })
    
    result = @service.periodic_data
    
    assert_equal 1234567890, result["result"]["last_balance_save"]
  end

  private

  def stub_rotki_api(method, path, response)
    base_url = ENV.fetch("ROTKI_API_URL", "http://localhost:5042")
    url = "#{base_url}#{path}"

    case method
    when :get
      stub_request(:get, url).to_return(body: response.to_json, headers: { "Content-Type" => "application/json" })
    when :post
      stub_request(:post, url).to_return(body: response.to_json, headers: { "Content-Type" => "application/json" })
    when :patch
      stub_request(:patch, url).to_return(body: response.to_json, headers: { "Content-Type" => "application/json" })
    end
  end
end
