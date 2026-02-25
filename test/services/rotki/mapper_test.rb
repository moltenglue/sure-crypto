require "test_helper"

class Rotki::MapperTest < ActiveSupport::TestCase
  setup do
    @mapper = Rotki::Mapper.new
  end

  # map_to_net_worth tests
  test "maps Rotki balance to net worth asset" do
    rotki_balance = {
      "ETH" => { "amount" => "1.5", "usd_value" => "4500.00" }
    }

    result = @mapper.map_to_net_worth(rotki_balance)

    assert_equal "1.5", result[:quantity]
    assert_equal 4500.00, result[:converted_value]
    assert_equal "ETH", result[:asset_symbol]
  end

  test "map_to_net_worth returns nil for blank input" do
    assert_nil @mapper.map_to_net_worth(nil)
    assert_nil @mapper.map_to_net_worth({})
    assert_nil @mapper.map_to_net_worth("")
  end

  test "map_to_net_worth returns nil for invalid data" do
    assert_nil @mapper.map_to_net_worth({ "ETH" => nil })
    assert_nil @mapper.map_to_net_worth({ nil => { "amount" => "1.0" } })
  end

  # map_balances tests
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

  test "map_balances returns nil for blank response" do
    assert_nil @mapper.map_balances(nil)
    assert_nil @mapper.map_balances({})
  end

  # calculate_net_worth tests
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

  test "calculate_net_worth returns 0 for empty total" do
    assert_equal 0, @mapper.calculate_net_worth({})
    assert_equal 0, @mapper.calculate_net_worth({ "total" => {} })
    assert_equal 0, @mapper.calculate_net_worth({ "total" => nil })
  end

  test "handles missing usd_value with null" do
    rotki_balance = {
      "DOGE" => { "amount" => "1000.0" }
    }

    result = @mapper.map_to_net_worth(rotki_balance)

    assert_equal "1000.0", result[:quantity]
    assert_nil result[:converted_value]
  end

  # Number format tests
  test "parse_usd_value handles US format with commas" do
    result = @mapper.send(:parse_usd_value, "1,234.56")
    assert_equal 1234.56, result
  end

  test "parse_usd_value handles European format" do
    result = @mapper.send(:parse_usd_value, "1.234,56")
    assert_equal 1234.56, result
  end

  test "parse_usd_value handles plain decimal" do
    result = @mapper.send(:parse_usd_value, "1234.56")
    assert_equal 1234.56, result
  end

  test "parse_usd_value handles European plain decimal" do
    result = @mapper.send(:parse_usd_value, "1234,56")
    assert_equal 1234.56, result
  end

  test "parse_usd_value handles numeric input" do
    result = @mapper.send(:parse_usd_value, 1234.56)
    assert_equal 1234.56, result
  end

  test "parse_usd_value handles nil" do
    assert_nil @mapper.send(:parse_usd_value, nil)
  end

  test "parse_usd_value handles invalid strings gracefully" do
    assert_nil @mapper.send(:parse_usd_value, "invalid")
    assert_nil @mapper.send(:parse_usd_value, "")
    assert_nil @mapper.send(:parse_usd_value, "   ")
  end

  # Edge case tests
  test "handles mixed number formats in same response" do
    rotki_response = {
      "total" => {
        "ETH" => { "amount" => "1,500.50", "usd_value" => "3,001.00" },
        "BTC" => { "amount" => "0.5", "usd_value" => "15.000,50" }
      }
    }

    result = @mapper.map_balances(rotki_response)

    assert_equal 2, result[:total].length
    assert_equal "1500.50", result[:total].first[:quantity]
    assert_equal 3001.0, result[:total].first[:converted_value]
  end

  test "handles very large numbers" do
    rotki_response = {
      "total" => {
        "SHIB" => { "amount" => "1000000000.0", "usd_value" => "10000.0" }
      }
    }

    result = @mapper.calculate_net_worth(rotki_response)
    assert_equal 10000.0, result
  end

  test "handles very small numbers" do
    rotki_response = {
      "total" => {
        "BTC" => { "amount" => "0.00000001", "usd_value" => "0.0005" }
      }
    }

    result = @mapper.calculate_net_worth(rotki_response)
    assert_in_delta 0.0005, result, 0.0001
  end
end