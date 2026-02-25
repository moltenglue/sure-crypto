class RotkiAccountsController < ApplicationController
  def new
    if Current.user.rotki_username.present? && Current.user.rotki_encrypted_password.present?
      @account = Current.family.accounts.build(
        currency: Current.family.currency,
        accountable: Crypto.new
      )
      render :new
    else
      redirect_to settings_providers_path, alert: t(".rotki_not_configured")
    end
  end

  def create
    unless Current.user.rotki_username.present? && Current.user.rotki_encrypted_password.present?
      return redirect_to settings_providers_path, alert: t(".rotki_not_configured")
    end

    rotki_item = ensure_rotki_item

    Rails.logger.info "RotkiAccountsController: rotki_item.rotki_accounts.count = #{rotki_item.rotki_accounts.count}"

    if rotki_item.rotki_accounts.empty?
      return redirect_to accounts_path, alert: "No balances found in Rotki. Make sure you have crypto in your Rotki portfolio."
    end

    created_accounts = []
    rotki_item.rotki_accounts.each do |rotki_account|
      account = Current.family.accounts.find_or_initialize_by(
        name: rotki_account.name,
        accountable_type: "Crypto"
      )

      if account.new_record?
        account.assign_attributes(
          balance: rotki_account.current_balance || 0,
          currency: Current.family.currency,
          accountable: Crypto.new(subtype: rotki_account.account_type)
        )
      end

      if account.save
        AccountProvider.find_or_create_by!(
          account: account,
          provider_account: rotki_account
        )
        created_accounts << account
      else
        Rails.logger.error "Failed to create account for #{rotki_account.name}: #{account.errors.full_messages.join(', ')}"
      end
    end

    if created_accounts.any?
      rotki_item.process_accounts
      sync_rotki_accounts(rotki_item)
      redirect_to accounts_path, notice: "Created #{created_accounts.count} Rotki accounts"
    else
      redirect_to accounts_path, alert: "Failed to create Rotki accounts"
    end
  rescue => e
    Rails.logger.error "RotkiAccountsController error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to accounts_path, alert: "Error connecting to Rotki: #{e.message}"
  end

  private

  def ensure_rotki_item
    Rails.logger.info "RotkiAccountsController: ensure_rotki_item called"
    
    existing = Current.family.rotki_items.active.first
    return existing if existing

    Rails.logger.info "RotkiAccountsController: Creating new rotki_item"
    
    rotki_item = Current.family.rotki_items.create!(
      name: "Rotki",
      status: "good"
    )

    Rails.logger.info "RotkiAccountsController: Current.user.rotki_username=#{Current.user.rotki_username.inspect}, rotki_encrypted_password present=#{Current.user.rotki_encrypted_password.present?}"
    
    rotki_service = RotkiService.new(
      username: Current.user.rotki_username,
      password: Current.user.rotki_encrypted_password
    )

    Rails.logger.info "RotkiAccountsController: Fetching balances from Rotki..."

    import_result = RotkiItem::Importer.new(rotki_item, rotki_service: rotki_service).import

    Rails.logger.info "RotkiAccountsController: Import result: #{import_result.inspect}"

    rotki_item.reload

    rotki_item
  end

  def sync_rotki_accounts(rotki_item)
    rotki_item.rotki_accounts.each do |rotki_account|
      next unless rotki_account.account_provider&.account

      rotki_account.account_provider.account.sync_later
    end
  end
end
