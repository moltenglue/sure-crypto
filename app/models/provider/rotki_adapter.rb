# Provider adapter for Rotki cryptocurrency portfolio integration.
# Handles connection to self-hosted Rotki instances.
class Provider::RotkiAdapter < Provider::Base
  # Register this adapter with the factory
  Provider::Factory.register("RotkiAccount", self)

  # @return [Array<String>] Account types supported by this provider
  def self.supported_account_types
    %w[Crypto]
  end

  # Returns connection configurations for this provider
  # @param family [Family] The family to check connection eligibility
  # @return [Array<Hash>] Connection config with name, description, and paths
  def self.connection_configs(family:)
    return [] unless family.can_connect_rotki?

    [ {
      key: "rotki",
      name: "Rotki",
      description: "Link to your self-hosted Rotki portfolio",
      can_connect: true,
      new_account_path: ->(accountable_type, return_to) {
        Rails.application.routes.url_helpers.new_rotki_account_path(
          accountable_type: accountable_type,
          return_to: return_to
        )
      },
      existing_account_path: nil
    } ]
  end

  # @return [String] Unique identifier for this provider
  def provider_name
    "rotki"
  end
end
