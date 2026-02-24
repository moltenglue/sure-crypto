module Rotki
  class BalanceCache
    CACHE_TTL = 5.minutes

    def initialize(service: RotkiService.new)
      @service = service
    end

    def get_balances(user, force_refresh: false)
      cache_key = "rotki_balances:#{user.id}"

      if force_refresh
        fetch_and_cache(user, cache_key)
      else
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          fetch_from_rotki(user)
        end
      end
    end

    private

    def fetch_and_cache(user, cache_key)
      data = fetch_from_rotki(user)
      Rails.cache.write(cache_key, data, expires_in: CACHE_TTL)
      data
    end

    def fetch_from_rotki(user)
      response = @service.balances
      raise RotkiServiceError, "Invalid response from Rotki" unless response["result"]
      response["result"]
    end
  end
end
