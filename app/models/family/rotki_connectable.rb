# Adds Rotki connection capabilities to Family.
# Rotki credentials are stored on the User model, not Family.
module Family::RotkiConnectable
  extend ActiveSupport::Concern

  # @return [Boolean] Whether the family can connect to Rotki
  def can_connect_rotki?
    true
  end

  # @return [Boolean] Whether any user in the family has Rotki configured
  def has_rotki_credentials?
    users.where.not(rotki_encrypted_password: nil).exists?
  end
end
