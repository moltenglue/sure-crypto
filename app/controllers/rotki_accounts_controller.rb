class RotkiAccountsController < ApplicationController
  def new
    if Current.user.rotki_encrypted_password.present?
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
    unless Current.user.rotki_encrypted_password.present?
      return redirect_to settings_providers_path, alert: t(".rotki_not_configured")
    end

    @account = Current.family.accounts.build(
      name: params[:account][:name],
      balance: 0,
      currency: Current.family.currency,
      accountable: Crypto.new(subtype: "exchange")
    )

    if @account.save
      redirect_to accounts_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end
end
