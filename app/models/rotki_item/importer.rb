class RotkiItem::Importer
  attr_reader :rotki_item, :rotki_service

  def initialize(rotki_item, rotki_service:)
    @rotki_item = rotki_item
    @rotki_service = rotki_service
  end

  def import
    Rails.logger.info "RotkiItem::Importer - Starting import for item #{rotki_item.id}"

    balances = rotki_service.all_balances

    Rails.logger.info "RotkiItem::Importer - Raw balances response: #{balances.inspect}"

    rotki_item.upsert_rotki_snapshot!(balances)

    accounts_imported = 0
    accounts_failed = 0

    import_blockchain_balances(balances[:blockchain])
    import_exchange_balances(balances[:exchanges])
    import_manual_balances(balances[:manual])

    accounts_imported = rotki_item.rotki_accounts.count

    Rails.logger.info "RotkiItem::Importer - Imported #{accounts_imported} accounts"

    { success: true, accounts_imported: accounts_imported, accounts_failed: accounts_failed }
  rescue => e
    Rails.logger.error "RotkiItem::Importer - Failed to import: #{e.message}"
    { success: false, accounts_imported: 0, accounts_failed: 0, error: e.message }
  end

  private

  def import_blockchain_balances(blockchain_data)
    return unless blockchain_data.present?

    per_chain = blockchain_data.dig("per_chain") || {}
    per_chain.each do |chain, chain_data|
      assets = chain_data["assets"] || []
      assets.each do |asset_data|
        import_balance(
          name: "#{chain} - #{asset_data["asset"]}",
          currency: asset_data["asset"],
          balance: asset_data.dig("amount", "amount") || asset_data["amount"],
          account_type: "blockchain",
          metadata: { chain: chain, category: "blockchain" }
        )
      end
    end
  end

  def import_exchange_balances(exchange_data)
    return unless exchange_data.present?

    locations = exchange_data.dig("location") || {}
    locations.each do |location, location_data|
      assets = location_data["assets"] || []
      assets.each do |asset_data|
        import_balance(
          name: "#{location} - #{asset_data["asset"]}",
          currency: asset_data["asset"],
          balance: asset_data.dig("amount", "amount") || asset_data["amount"],
          account_type: "exchange",
          metadata: { location: location, category: "exchange" }
        )
      end
    end
  end

  def import_manual_balances(manual_data)
    return unless manual_data.present?

    entries = manual_data || []
    entries.each do |entry|
      import_balance(
        name: entry["label"] || entry["asset"],
        currency: entry["asset"],
        balance: entry.dig("amount", "amount") || entry["amount"],
        account_type: "manual",
        metadata: { category: "manual" }
      )
    end
  end

  def import_balance(name:, currency:, balance:, account_type:, metadata: {})
    balance_decimal = BigDecimal(balance.to_s)

    return if balance_decimal.zero?

    rotki_account = rotki_item.rotki_accounts.find_or_initialize_by(
      currency: currency,
      account_type: account_type,
      name: name
    )

    rotki_account.assign_attributes(
      current_balance: balance_decimal,
      institution_metadata: metadata.merge({
        "name" => "Rotki",
        "domain" => "rotki.com"
      }),
      raw_payload: metadata,
      provider: "rotki"
    )

    rotki_account.save!
  rescue => e
    Rails.logger.error "RotkiItem::Importer - Failed to import balance #{name}: #{e.message}"
  end
end
