require "test_helper"

class Rotki::BalanceCacheTest < ActiveSupport::TestCase
  setup do
    @cache = Rotki::BalanceCache.new
    @user = users(:one)
  end

  test "fetches fresh balances from Rotki" do
    RotkiService.any_instance.expects(:balances).returns({
      "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
      "message" => ""
    })

    result = @cache.get_balances(@user)

    assert_equal "1.0", result.dig("total", "ETH", "amount")
  end

  test "uses cache when fresh" do
    cached_data = { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } }
    Rails.cache.write("rotki_balances:#{@user.id}", cached_data, expires_in: 5.minutes)

    result = @cache.get_balances(@user)

    assert_equal "1.0", result.dig("total", "ETH", "amount")
  end
end
