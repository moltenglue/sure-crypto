module Rotki
  class Mapper
    # Parse currency values from Rotki API
    # Handles various international formats:
    # - US/UK: 1,234.56
    # - European: 1.234,56
    # - Plain: 1234.56
    def map_to_net_worth(balance_entry)
      return nil if balance_entry.blank?
      asset_symbol, data = balance_entry.first
      return nil unless data

      {
        asset_symbol: asset_symbol,
        quantity: parse_quantity(data["amount"]),
        converted_value: parse_usd_value(data["usd_value"])
      }
    end

    def map_balances(response)
      return nil if response.blank?

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
      return nil unless section.is_a?(Hash)

      section.map { |asset, data| map_to_net_worth({ asset => data }) }.compact
    end

    def parse_quantity(value)
      return nil if value.nil?
      return value.to_s if value.is_a?(String)
      return value.to_d.to_s if value.is_a?(Numeric)

      value.to_s
    end

    # Parse USD value, handling various number formats
    # Rotki typically returns values as strings or floats
    def parse_usd_value(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric)

      value_str = value.to_s.strip

      # Handle different number formats
      case value_str
      when /^(\d{1,3}(,\d{3})*(\.\d+)?)$/  # US format: 1,234.56
        value_str.gsub(",", "").to_f
      when /^(\d{1,3}(\.\d{3})*(,\d+)?)$/  # European format: 1.234,56
        value_str.gsub(".", "").gsub(",", ".").to_f
      when /^\d+\.\d+$/                     # Plain decimal: 1234.56
        value_str.to_f
      when /^\d+,\d+$/                      # European plain: 1234,56
        value_str.gsub(",", ".").to_f
      else
        # Try to parse as float, default to 0 if invalid
        Float(value_str) rescue nil
      end
    end
  end
end