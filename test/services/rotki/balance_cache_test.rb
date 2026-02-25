require "test_helper"

class Rotki::BalanceCacheTest < ActiveSupport::TestCase
  setup do
    @cache = Rotki::BalanceCache.new
    @user = users(:family_admin)
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "requires user parameter" do
    assert_raises(ArgumentError) do
      @cache.get_balances(nil)
    end

    assert_raises(ArgumentError) do
      @cache.get_balances("not a user")
    end
  end

  test "raises error when rotki not configured" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: nil)

    assert_raises(Rotki::RotkiServiceError) do
      @cache.get_balances(@user)
    end
  end

  test "fetches and caches balances" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).returns({
      "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      "message" => ""
    })
    @user.expects(:rotki_service).returns(mock_service)

    result = @cache.get_balances(@user)

    assert_equal({ "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }, result["total"])

    # Verify it was cached
    cache_key = "rotki_balances:#{@user.id}"
    cached = Rails.cache.read(cache_key)
    assert_equal result, cached
  end

  test "returns cached data on subsequent calls" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).once.returns({
      "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      "message" => ""
    })
    @user.expects(:rotki_service).once.returns(mock_service)

    # First call
    result1 = @cache.get_balances(@user)
    # Second call should use cache
    result2 = @cache.get_balances(@user)

    assert_equal result1, result2
  end

  test "force_refresh bypasses cache" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).twice.returns({
      "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      "message" => ""
    })
    @user.expects(:rotki_service).twice.returns(mock_service)

    # First call
    @cache.get_balances(@user)
    # Force refresh should fetch again
    @cache.get_balances(@user, force_refresh: true)
  end

  test "raises error on invalid response" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).returns({ "error" => "Auth failed", "message" => "" })
    @user.expects(:rotki_service).returns(mock_service)

    assert_raises(Rotki::RotkiServiceError) do
      @cache.get_balances(@user)
    end
  end

  test "raises error when service returns nil" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).returns(nil)
    @user.expects(:rotki_service).returns(mock_service)

    assert_raises(Rotki::RotkiServiceError) do
      @cache.get_balances(@user)
    end
  end

  test "clear_cache removes cached data" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    mock_service = mock("rotki_service")
    mock_service.expects(:balances).returns({
      "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      "message" => ""
    })
    @user.expects(:rotki_service).returns(mock_service)

    @cache.get_balances(@user)

    cache_key = "rotki_balances:#{@user.id}"
    assert Rails.cache.exist?(cache_key)

    @cache.clear_cache(@user)

    assert_not Rails.cache.exist?(cache_key)
  end

  test "uses cache when fresh" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted_pass")

    cached_data = { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } }
    Rails.cache.write("rotki_balances:#{@user.id}", cached_data, expires_in: 5.minutes)

    # Service should NOT be called when data is cached
    @user.expects(:rotki_service).never

    result = @cache.get_balances(@user)

    assert_equal "1.0", result.dig("total", "ETH", "amount")
  end
end