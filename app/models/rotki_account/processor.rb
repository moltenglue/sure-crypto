class RotkiAccount::Processor
  attr_reader :rotki_account

  def initialize(rotki_account)
    @rotki_account = rotki_account
  end

  def process
    unless rotki_account.current_account.present?
      Rails.logger.info "RotkiAccount::Processor - No linked account for rotki_account #{rotki_account.id}, skipping processing"
      return
    end

    Rails.logger.info "RotkiAccount::Processor - Processing rotki_account #{rotki_account.id}"

    process_account!
  end

  private

  def process_account!
    account = rotki_account.current_account

    balance = rotki_account.current_balance || 0

    Rails.logger.info(
      "RotkiAccount::Processor - Updating account #{account.id} balance: #{balance} #{rotki_account.currency}"
    )

    account.update!(
      balance: balance,
      currency: account.currency || "USD"
    )
  end
end
