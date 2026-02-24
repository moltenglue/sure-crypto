require "test_helper"

class Rotki::MapperTest < ActiveSupport::TestCase
  setup do
    @mapper = Rotki::Mapper.new
  end

  test "maps Rotki balance to net worth asset" do
    rotki_balance = {
      "ETH" => { "amount" => "1.5", "usd_value" => "4500.00" }
    }

    result = @mapper.map_to_net_worth(rotki_balance)

    assert_equal "1.5", result[:quantity]
    assert_equal 4500.00, result[:converted_value]
    assert_equal "ETH", result[:asset_symbol]
  end

  test "handles nested balance structure" do
    rotki_response = {
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.00" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.00" }
      },
      "blockchain" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.00" }
      }
    }

    result = @mapper.map_balances(rotki_response)

    assert_equal 2, result[:total].size
    assert_equal 1, result[:blockchain].size
  end

  test "calculates net worth from total balances" do
    rotki_response = {
      "total" => {
        "ETH" => { "amount" => "1.0", "usd_value" => "3000.00" },
        "BTC" => { "amount" => "0.1", "usd_value" => "5000.00" }
      }
    }

    result = @mapper.calculate_net_worth(rotki_response)

    assert_equal 8000.00, result
  end

  test "handles missing usd_value with null" do
    rotki_balance = {
      "DOGE" => { "amount" => "1000.0" }
    }

    result = @mapper.map_to_net_worth(rotki_balance)

    assert_equal "1000.0", result[:quantity]
    assert_nil result[:converted_value]
  end
end
