class Settings::RotkiController < ApplicationController
  layout "settings"

  def connect
    password = params.require(:password)

    begin
      Current.user.authenticate_with_rotki!(password)
      redirect_to settings_providers_path, notice: t(".success")
    rescue RotkiServiceError => e
      Rails.logger.error "Rotki connect error: #{e.message}"
      redirect_to settings_providers_path, alert: t(".error", message: "Unable to connect to Rotki. Please check your password.")
    rescue => e
      Rails.logger.error "Rotki connect error: #{e.message}"
      redirect_to settings_providers_path, alert: t(".error", message: "An unexpected error occurred")
    end
  end

  def disconnect
    Current.user.update!(rotki_encrypted_password: nil)
    redirect_to settings_providers_path, notice: t(".disconnect_success")
  rescue => e
    Rails.logger.error "Rotki disconnect error: #{e.message}"
    redirect_to settings_providers_path, alert: t(".disconnect_error")
  end
end
