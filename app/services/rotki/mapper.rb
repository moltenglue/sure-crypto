module Rotki
  class Mapper
    def map_to_net_worth(balance_entry)
      asset_symbol, data = balance_entry.first
      
      {
        asset_symbol: asset_symbol,
        quantity: data["amount"],
        converted_value: parse_usd_value(data["usd_value"])
      }
    end

    def map_balances(response)
      {
        total: map_section(response["total"]),
        blockchain: map_section(response["blockchain"]),
        exchanges: map_section(response["exchanges"]),
        manual: map_section(response["manual"])
      }.compact
    end

    def calculate_net_worth(response)
      return 0 unless response["total"]

      response["total"].sum do |_asset, data|
        parse_usd_value(data["usd_value"]) || 0
      end
    end

    private

    def map_section(section)
      return nil unless section

      section.map { |asset, data| map_to_net_worth({ asset => data }) }
    end

    def parse_usd_value(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric)
      
      value.to_s.gsub(",", "").to_f
    end
  end
end
