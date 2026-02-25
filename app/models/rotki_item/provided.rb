module RotkiItem::Provided
  extend ActiveSupport::Concern

  def rotki_provider
    return nil unless credentials_configured?

    creds = rotki_credentials
    return nil unless creds

    RotkiService.new(username: creds[:username], password: creds[:password])
  end
end
