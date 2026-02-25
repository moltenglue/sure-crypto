class Settings::RotkiController < ApplicationController
  class RotkiConnectionError < StandardError; end

  layout "settings"

  before_action :require_admin!, only: [:connect, :disconnect]
  before_action :validate_rotki_params, only: [:connect]

  def connect
    begin
      Current.user.authenticate_with_rotki!(
        params[:rotki_username],
        params[:password]
      )
      redirect_to settings_providers_path, notice: t(".success")
    rescue RotkiUserConcern::RotkiConnectionError => e
      Rails.logger.error "Rotki connect error: #{e.message}"
      redirect_to settings_providers_path, alert: t(".error", message: "Unable to connect to Rotki. Please check your credentials.")
    rescue => e
      Rails.logger.error "Rotki connect error: #{e.message}"
      redirect_to settings_providers_path, alert: t(".error", message: "An unexpected error occurred")
    end
  end

  def disconnect
    if Current.user.disconnect_rotki!
      redirect_to settings_providers_path, notice: t(".disconnect_success")
    else
      redirect_to settings_providers_path, alert: t(".disconnect_error")
    end
  rescue => e
    Rails.logger.error "Rotki disconnect error: #{e.message}"
    redirect_to settings_providers_path, alert: t(".disconnect_error")
  end

  private

  def require_admin!
    unless Current.user.admin?
      redirect_to settings_providers_path, alert: t("settings.rotki.unauthorized")
    end
  end

  def validate_rotki_params
    if params[:rotki_username].blank?
      return redirect_to settings_providers_path, alert: t(".error", message: "Username is required")
    end

    if params[:password].blank?
      return redirect_to settings_providers_path, alert: t(".error", message: "Password is required")
    end

    if params[:password].length < 6
      return redirect_to settings_providers_path, alert: t(".error", message: "Password must be at least 6 characters")
    end
  end
end