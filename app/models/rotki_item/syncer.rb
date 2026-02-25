class RotkiItem::Syncer
  include SyncStats::Collector

  attr_reader :rotki_item

  def initialize(rotki_item)
    @rotki_item = rotki_item
  end

  def perform_sync(sync)
    sync.update!(status_text: "Checking credentials") if sync.respond_to?(:status_text)

    unless rotki_item.credentials_configured?
      rotki_item.update!(status: :requires_update)
      mark_failed(sync, "Rotki credentials not configured")
      return
    end

    sync.update!(status_text: "Importing balances") if sync.respond_to?(:status_text)
    rotki_item.import_latest_rotki_data

    sync.update!(status_text: "Checking configuration") if sync.respond_to?(:status_text)

    collect_setup_stats(sync, provider_accounts: rotki_item.rotki_accounts.to_a)

    unlinked = rotki_item.rotki_accounts.left_joins(:account_provider).where(account_providers: { id: nil })
    linked = rotki_item.rotki_accounts.joins(:account_provider).joins(:account).merge(Account.visible)

    if unlinked.any?
      rotki_item.update!(pending_account_setup: true)
    else
      rotki_item.update!(pending_account_setup: false)
    end

    if linked.any?
      sync.update!(status_text: "Processing accounts") if sync.respond_to?(:status_text)
      rotki_item.process_accounts

      sync.update!(status_text: "Calculating balances") if sync.respond_to?(:status_text)
      rotki_item.schedule_account_syncs(
        parent_sync: sync,
        window_start_date: sync.window_start_date,
        window_end_date: sync.window_end_date
      )
    end
  end

  def perform_post_sync
  end

  private

  def mark_failed(sync, error_message)
    if sync.respond_to?(:status) && sync.status.to_s == "completed"
      Rails.logger.warn("RotkiItem::Syncer#mark_failed called after completion: #{error_message}")
      return
    end

    sync.start! if sync.respond_to?(:may_start?) && sync.may_start?

    if sync.respond_to?(:may_fail?) && sync.may_fail?
      sync.fail!
    elsif sync.respond_to?(:status)
      sync.update!(status: :failed)
    end

    sync.update!(error: error_message) if sync.respond_to?(:error)
    sync.update!(status_text: error_message) if sync.respond_to?(:status_text)
  end
end
