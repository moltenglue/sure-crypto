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
