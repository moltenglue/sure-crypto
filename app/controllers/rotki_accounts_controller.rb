class RotkiAccountsController < ApplicationController
  before_action :require_rotki_configured!, only: [:new, :create]
  before_action :require_admin!, only: [:create]

  def new
    @account = Current.family.accounts.build(
      currency: Current.family.currency,
      accountable: Crypto.new
    )
  end

  def create
    rotki_item = ensure_rotki_item

    Rails.logger.info "RotkiAccountsController: rotki_item.rotki_accounts.count = #{rotki_item.rotki_accounts.count}"

    if rotki_item.rotki_accounts.empty?
      return redirect_to accounts_path, alert: "No balances found in Rotki. Make sure you have crypto in your Rotki portfolio."
    end

    created_accounts = create_rotki_accounts(rotki_item)

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

  def require_rotki_configured!
    unless Current.user.rotki_configured?
      redirect_to settings_providers_path, alert: t(".rotki_not_configured")
    end
  end

  def require_admin!
    unless Current.user.admin?
      redirect_to accounts_path, alert: t(".unauthorized")
    end
  end

  def ensure_rotki_item
    Rails.logger.info "RotkiAccountsController: ensure_rotki_item called"

    Current.family.rotki_items.active.first || create_rotki_item
  end

  def create_rotki_item
    Rails.logger.info "RotkiAccountsController: Creating new rotki_item"

    rotki_item = Current.family.rotki_items.create!(
      name: "Rotki",
      status: "good"
    )

    Rails.logger.info "RotkiAccountsController: Current.user.rotki_configured?=#{Current.user.rotki_configured?}"

    rotki_service = Current.user.rotki_service
    raise RotkiConnectionError, "Rotki service not available" unless rotki_service

    Rails.logger.info "RotkiAccountsController: Fetching balances from Rotki..."

    import_result = RotkiItem::Importer.new(rotki_item, rotki_service: rotki_service).import

    Rails.logger.info "RotkiAccountsController: Import result: #{import_result.inspect}"

    rotki_item.reload
    rotki_item
  end

  def create_rotki_accounts(rotki_item)
    created_accounts = []

    rotki_item.rotki_accounts.find_each do |rotki_account|
      begin
        account = create_or_update_account(rotki_account)
        created_accounts << account if account.persisted?
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create account for #{rotki_account.name}: #{e.message}"
      rescue => e
        Rails.logger.error "Unexpected error creating account for #{rotki_account.name}: #{e.message}"
      end
    end

    created_accounts
  end

  def create_or_update_account(rotki_account)
    # Use find_or_initialize_by with accountable_type to prevent duplicates
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

    Account.transaction do
      account.save!

      AccountProvider.find_or_create_by!(
        account: account,
        provider_account: rotki_account
      )
    end

    account
  end

  def sync_rotki_accounts(rotki_item)
    rotki_item.rotki_accounts.each do |rotki_account|
      next unless rotki_account.account_provider&.account

      rotki_account.account_provider.account.sync_later
    end
  end

  class RotkiConnectionError < StandardError; end
end