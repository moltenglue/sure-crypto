module Rotki
  class BalanceCache
    CACHE_TTL = 5.minutes

    def get_balances(user, force_refresh: false)
      raise ArgumentError, "User is required" unless user.is_a?(User)

      cache_key = "rotki_balances:#{user.id}"

      if force_refresh
        fetch_and_cache(user, cache_key)
      else
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_from_rotki(user)
        end
      end
    end

    def clear_cache(user)
      cache_key = "rotki_balances:#{user.id}"
      Rails.cache.delete(cache_key)
    end

    private

    def fetch_and_cache(user, cache_key)
      data = fetch_from_rotki(user)
      Rails.cache.write(cache_key, data, expires_in: CACHE_TTL)
      data
    end

    def fetch_from_rotki(user)
      service = user.rotki_service

      unless service
        raise RotkiServiceError, "Rotki not configured for user #{user.id}"
      end

      response = service.balances

      unless response.is_a?(Hash) && response.key?("result")
        raise RotkiServiceError, "Invalid response from Rotki API"
      end

      response["result"]
    rescue RotkiServiceError
      raise
    rescue => e
      Rails.logger.error "Rotki BalanceCache fetch error for user #{user.id}: #{e.message}"
      raise RotkiServiceError, "Failed to fetch balances from Rotki"
    end
  end

  class RotkiServiceError < StandardError; end
end