require "test_helper"

class RotkiServiceTest < ActiveSupport::TestCase
  setup do
    @service = RotkiService.new
  end

  test "creates user in Rotki" do
    stub_rotki_api(:post, "/api/1/users", { "result" => true, "message" => "" })

    result = @service.create_user("testuser", "password123")

    assert_equal true, result
  end

  test "login authenticates against Rotki and captures session cookie" do
    stub_rotki_api_with_cookie(:post, "/api/1/users/testuser", { "result" => true, "message" => "" }, "rotki_session=test_session_token")

    result = @service.login("testuser", "password123")

    assert_equal({ "success" => true }, result)
  end

  test "login retries after logout on 409 conflict" do
    RotkiService.any_instance.stubs(:logout)
    @service = RotkiService.new(username: "testuser", password: "password123")

    stub_rotki_api(:post, "/api/1/users/testuser", { "result" => false, "message" => "Already logged in" }, status: 409)
    stub_rotki_api_with_cookie(:patch, "/api/1/users/testuser", { "result" => true, "message" => "" }, nil)
    stub_rotki_api_with_cookie(:post, "/api/1/users/testuser", { "result" => true, "message" => "" }, "rotki_session=retry_token")

    result = @service.login("testuser", "password123")

    assert_equal({ "success" => true, "message" => "User already exists" }, result)
  end

  test "login returns success for 409 conflict after retry fails" do
    @service = RotkiService.new(username: "testuser", password: "password123")

    stub_rotki_api(:post, "/api/1/users/testuser", { "result" => false, "message" => "Already logged in" }, status: 409)
    stub_rotki_api_with_cookie(:patch, "/api/1/users/testuser", { "result" => true, "message" => "" }, nil)
    stub_rotki_api(:post, "/api/1/users/testuser", { "result" => false, "message" => "Retry failed" }, status: 409)

    result = @service.login("testuser", "password123")

    assert_equal({ "success" => true, "message" => "User already exists" }, result)
  end

  test "logout sends patch request with action logout" do
    @service = RotkiService.new(username: "testuser", password: "password123")
    @service.instance_variable_set(:@session_cookie, "rotki_session=some_token")

    stub_rotki_api(:patch, "/api/1/users/testuser", { "result" => true, "message" => "" })

    result = @service.logout("testuser")

    assert_equal true, result["result"]
  end

  test "all_balances fetches blockchain, exchange, and manual balances" do
    @service = RotkiService.new(username: "testuser", password: "password123")

    stub_rotki_api_with_cookie(:post, "/api/1/users/testuser", { "result" => true, "message" => "" }, "rotki_session=token")
    stub_rotki_api(:get, "/api/1/balances/blockchain", { "result" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }, "message" => "" })
    stub_rotki_api(:get, "/api/1/balances/exchanges", { "result" => { "binance" => { "total" => { "BTC" => { "amount" => "0.5" } } } }, "message" => "" })
    stub_rotki_api(:get, "/api/1/balances/manual", { "result" => [ { "label" => "My Wallet", "amount" => "1000", "currency" => "USD" } ], "message" => "" })

    result = @service.all_balances

    assert_equal "1.0", result[:blockchain]["result"]["ETH"]["amount"]
    assert_equal "0.5", result[:exchanges]["result"]["binance"]["total"]["BTC"]["amount"]
    assert_equal 1, result[:manual]["result"].size
  end

  test "fetches balances from /api/1/balances" do
    stub_rotki_api(:get, "/api/1/balances", { "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } }, "message" => "" })

    result = @service.balances

    assert_equal "1.0", result["total"]["ETH"]["amount"]
  end

  test "fetches blockchain balances" do
    stub_rotki_api(:get, "/api/1/balances/blockchain", { "result" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }, "message" => "" })

    result = @service.blockchain_balances

    assert_equal "1.0", result["ETH"]["amount"]
  end

  test "fetches exchange balances" do
    stub_rotki_api(:get, "/api/1/balances/exchanges", { "result" => { "binance" => { "total" => { "BTC" => { "amount" => "0.5" } } } }, "message" => "" })

    result = @service.exchange_balances

    assert_equal "0.5", result["binance"]["total"]["BTC"]["amount"]
  end

  test "fetches manual balances" do
    stub_rotki_api(:get, "/api/1/balances/manual", { "result" => [ { "label" => "My Wallet", "amount" => "1000", "currency" => "USD" } ], "message" => "" })

    result = @service.manual_balances

    assert_equal 1, result.size
  end

  test "fetches periodic data" do
    stub_rotki_api(:get, "/api/1/periodic", { "result" => { "last_balance_save" => 1234567890 }, "message" => "" })

    result = @service.periodic_data

    assert_equal 1234567890, result["last_balance_save"]
  end

  test "raises error on non-success response" do
    stub_rotki_api(:get, "/api/1/balances", { "result" => false, "message" => "Server error" }, status: 500)

    assert_raises(RuntimeError, "Rotki API error: 500 - Internal Server Error") do
      @service.balances
    end
  end

  test "raises error when Rotki returns error in response" do
    stub_rotki_api(:get, "/api/1/balances", { "result" => false, "error" => "Authentication required", "message" => "" })

    assert_raises(RuntimeError, "Rotki API error: Authentication required") do
      @service.balances
    end
  end

  test "ensure_logged_in raises when username not provided" do
    @service = RotkiService.new(password: "password123")

    assert_raises(RuntimeError, "Rotki username not provided") do
      @service.ensure_logged_in
    end
  end

  test "ensure_logged_in raises when password not provided" do
    @service = RotkiService.new(username: "testuser")

    assert_raises(RuntimeError, "Rotki password not provided") do
      @service.ensure_logged_in
    end
  end

  test "ensure_logged_in does nothing when already logged in" do
    @service = RotkiService.new(username: "testuser", password: "password123")
    @service.instance_variable_set(:@session_cookie, "rotki_session=existing_token")

    result = @service.ensure_logged_in

    assert_nil result
  end

  test "login with credentials calls login with correct username" do
    @service = RotkiService.new(username: "testuser", password: "password123")
    RotkiService.any_instance.expects(:login).with("testuser", "password123").returns({ "success" => true })

    result = @service.ensure_logged_in

    assert_nil result
  end

  test "includes session cookie in requests when logged in" do
    @service = RotkiService.new(username: "testuser", password: "password123")
    @service.instance_variable_set(:@session_cookie, "rotki_session=my_session_token")

    base_url = "http://localhost:5042"
    url = "#{base_url}/api/1/balances"

    stub_request(:get, url).with(headers: { "Cookie" => "rotki_session=my_session_token" })
      .to_return(body: { "result" => { "total" => {} }, "message" => "" }.to_json, headers: { "Content-Type" => "application/json" })

    @service.balances

    assert_requested :get, url, headers: { "Cookie" => "rotki_session=my_session_token" }
  end

  private

    def stub_rotki_api(method, path, response, status: 200)
      base_url = ENV.fetch("ROTKI_API_URL", "http://localhost:5042")
      url = "#{base_url}#{path}"

      case method
      when :get
        stub_request(:get, url).to_return(body: response.to_json, status: status, headers: { "Content-Type" => "application/json" })
      when :post
        stub_request(:post, url).to_return(body: response.to_json, status: status, headers: { "Content-Type" => "application/json" })
      when :patch
        stub_request(:patch, url).to_return(body: response.to_json, status: status, headers: { "Content-Type" => "application/json" })
      end
    end

    def stub_rotki_api_with_cookie(method, path, response, cookie, status: 200)
      base_url = ENV.fetch("ROTKI_API_URL", "http://localhost:5042")
      url = "#{base_url}#{path}"

      headers = { "Content-Type" => "application/json" }
      headers["Set-Cookie"] = "rotki_session=#{cookie}" if cookie

      case method
      when :get
        stub_request(:get, url).to_return(body: response.to_json, status: status, headers: headers)
      when :post
        stub_request(:post, url).to_return(body: response.to_json, status: status, headers: headers)
      when :patch
        stub_request(:patch, url).to_return(body: response.to_json, status: status, headers: headers)
      end
    end
end
