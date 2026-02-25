module RotkiUserConcern
  extend ActiveSupport::Concern

  class_methods do
    def with_rotki_configured
      where.not(rotki_username: nil, rotki_encrypted_password: nil)
    end
  end

  def rotki_configured?
    rotki_username.present? && rotki_encrypted_password.present?
  end

  def rotki_service
    return nil unless rotki_configured?

    password = decrypt_rotki_password
    return nil if password.blank?

    RotkiService.new(username: rotki_username, password: password)
  end

  def authenticate_with_rotki!(username, password)
    service = RotkiService.new(username: username, password: password)
    result = service.login(username, password)

    encrypted = encrypt_rotki_password(password)
    raise RotkiConnectionError, "Failed to encrypt password" if encrypted.blank?

    update!(
      rotki_encrypted_password: encrypted,
      rotki_username: username
    )

    result
  rescue => e
    Rails.logger.error "Rotki authentication failed for user #{id}: #{e.message}"
    raise RotkiConnectionError, "Unable to connect to Rotki"
  end

  def disconnect_rotki!
    return true unless rotki_configured?

    begin
      service = rotki_service
      service&.logout(rotki_username)
    rescue => e
      Rails.logger.warn "Rotki logout failed for user #{id}: #{e.message}"
    ensure
      update!(rotki_encrypted_password: nil, rotki_username: nil)
    end

    true
  end

  def sync_to_rotki
    return unless rotki_configured?

    password = decrypt_rotki_password
    return if password.blank?

    RotkiService.new.create_user(email, password)
  rescue => e
    Rails.logger.error "Failed to sync user #{id} to Rotki: #{e.message}"
    nil
  end

  class RotkiConnectionError < StandardError; end
end