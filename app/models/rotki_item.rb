class RotkiItem < ApplicationRecord
  include Syncable, Unlinking

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  belongs_to :family
  has_many :rotki_accounts, dependent: :destroy
  has_many :accounts, through: :rotki_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :syncable, -> { active }
  scope :ordered, -> { order(created_at: :desc) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def import_latest_rotki_data
    rotki = rotki_service
    unless rotki
      Rails.logger.error "RotkiItem #{id} - Cannot import: service not available"
      raise StandardError.new("Rotki service not available")
    end

    RotkiItem::Importer.new(self, rotki_service: rotki).import
  rescue => e
    Rails.logger.error "RotkiItem #{id} - Failed to import data: #{e.message}"
    raise
  end

  def process_accounts
    Rails.logger.info "RotkiItem #{id} - process_accounts: total rotki_accounts=#{rotki_accounts.count}"

    return [] if rotki_accounts.empty?

    linked = rotki_accounts.joins(:account).merge(Account.visible)
    Rails.logger.info "RotkiItem #{id} - found #{linked.count} linked visible accounts to process"

    results = []
    linked.each do |rotki_account|
      begin
        Rails.logger.info "RotkiItem #{id} - processing rotki_account #{rotki_account.id}"
        result = RotkiAccount::Processor.new(rotki_account).process
        results << { rotki_account_id: rotki_account.id, success: true, result: result }
      rescue => e
        Rails.logger.error "RotkiItem #{id} - Failed to process account #{rotki_account.id}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        results << { rotki_account_id: rotki_account.id, success: false, error: e.message }
      end
    end

    results
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    return [] if accounts.empty?

    results = []
    accounts.visible.each do |account|
      begin
        account.sync_later(
          parent_sync: parent_sync,
          window_start_date: window_start_date,
          window_end_date: window_end_date
        )
        results << { account_id: account.id, success: true }
      rescue => e
        Rails.logger.error "RotkiItem #{id} - Failed to schedule sync for account #{account.id}: #{e.message}"
        results << { account_id: account.id, success: false, error: e.message }
      end
    end

    results
  end

  def upsert_rotki_snapshot!(accounts_snapshot)
    assign_attributes(raw_payload: accounts_snapshot)
    save!
  end

  def credentials_configured?
    family.users.where.not(rotki_username: nil, rotki_encrypted_password: nil).exists?
  end

  def rotki_credentials
    user = family.users.where.not(rotki_username: nil, rotki_encrypted_password: nil).first
    return nil unless user

    {
      username: user.rotki_username,
      password: user.rotki_encrypted_password
    }
  end

  def rotki_service
    creds = rotki_credentials
    return nil unless creds

    RotkiService.new(username: creds[:username], password: creds[:password])
  end

  def sync_status_summary
    total = total_accounts_count
    linked = linked_accounts_count
    unlinked = unlinked_accounts_count

    if total == 0
      "No accounts"
    elsif unlinked == 0
      "All synced (#{linked})"
    else
      "#{linked} synced, #{unlinked} need setup"
    end
  end

  def linked_accounts_count
    rotki_accounts.joins(:account_provider).count
  end

  def unlinked_accounts_count
    rotki_accounts.left_joins(:account_provider).where(account_providers: { id: nil }).count
  end

  def total_accounts_count
    rotki_accounts.count
  end
end
