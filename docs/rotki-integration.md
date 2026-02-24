# Rotki Integration Documentation

## Overview

The Rotki integration enables Sure to import and display cryptocurrency holdings from a user's Rotki instance. Rotki is a self-hosted, open-source portfolio tracking, analytics, and accounting tool that supports 80+ exchanges, multiple blockchains, and DeFi protocols.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sure Application                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │  RotkiController │───▶│ Rotki::BalanceCache│                │
│  │  (API Endpoints) │    │ (5-min TTL Cache) │                 │
│  └──────────────────┘    └────────┬─────────┘                  │
│                                    │                            │
│                          ┌─────────▼─────────┐                  │
│                          │   RotkiService    │                  │
│                          │ (HTTP Client)     │                  │
│                          └────────┬─────────┘                  │
└───────────────────────────────────┼────────────────────────────┘
                                    │
                                    ▼
                          ┌──────────────────┐
                          │  Rotki Instance  │
                          │  (External API)  │
                          └──────────────────┘
```

## Components

### 1. RotkiService (`app/services/rotki_service.rb`)

Low-level HTTP client for communicating with the Rotki API.

**Features:**
- Base URL configurable via `ROTKI_API_URL` environment variable
- Support for user creation, authentication, and logout
- Methods for fetching various balance types
- HTTP timeout protection (10s connect, 30s read)
- Proper error handling with custom `RotkiServiceError` class

**API Methods:**
| Method | Endpoint | Description |
|--------|----------|-------------|
| `create_user(username, password)` | POST /api/1/users | Create new Rotki user |
| `login(username, password)` | POST /api/1/users/{username} | Authenticate user |
| `logout(username)` | PATCH /api/1/users/{username} | Logout user |
| `balances` | GET /api/1/balances | Get all balances |
| `blockchain_balances` | GET /api/1/balances/blockchain | Get blockchain balances |
| `exchange_balances` | GET /api/1/balances/exchanges | Get exchange balances |
| `manual_balances` | GET /api/1/balances/manual | Get manually tracked balances |
| `periodic_data` | GET /api/1/periodic | Get periodic data |

### 2. Rotki::Mapper (`app/services/rotki/mapper.rb`)

Transforms Rotki API responses into Sure's internal format.

**Methods:**
| Method | Input | Output |
|--------|-------|--------|
| `map_to_net_worth(balance_entry)` | `{ "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } }` | `{ asset_symbol: "ETH", quantity: "1.0", converted_value: 3000.0 }` |
| `map_balances(response)` | Full Rotki response | Hash with `:total`, `:blockchain`, `:exchanges`, `:manual` keys |
| `calculate_net_worth(response)` | Full Rotki response | Float total USD value |

### 3. Rotki::BalanceCache (`app/services/rotki/balance_cache.rb`)

Caches balance responses to reduce API calls and improve performance.

**Features:**
- 5-minute TTL (configurable via `CACHE_TTL`)
- Per-user cache keys (`rotki_balances:{user_id}`)
- Force refresh option for manual cache invalidation

### 4. RotkiController (`app/controllers/api/v1/rotki_controller.rb`)

RESTful API endpoints for the frontend.

**Endpoints:**
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/rotki/balances | read scope | Fetch cached balances |
| POST | /api/v1/rotki/connect | write scope | Connect to Rotki with password |

**Response Format:**
```json
{
  "net_worth": 8000.00,
  "balances": {
    "total": [
      { "asset_symbol": "ETH", "quantity": "1.0", "converted_value": 3000.00 },
      { "asset_symbol": "BTC", "quantity": "0.1", "converted_value": 5000.00 }
    ],
    "blockchain": [...],
    "exchanges": [...],
    "manual": [...]
  },
  "cached_at": "2026-02-24T12:00:00Z"
}
```

### 5. Frontend Controller (`app/javascript/controllers/rotki_controller.js`)

StimulusJS controller for the Rotki connection UI.

**Features:**
- Connect form with password input
- Automatic balance fetching on page load
- XSS-safe HTML rendering
- Loading state management
- Currency formatting

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ROTKI_API_URL` | http://localhost:5042 | Rotki API endpoint |

### Docker Compose

Add to your `docker-compose.yml`:

```yaml
services:
  rotki:
    image: rotki/rotki:latest
    container_name: sure-rotki
    ports:
      - "5042:5042"
    volumes:
      - rotki-data:/data
    environment:
      - ROTKI_IS_HEADLESS=true
      - API_UPLOAD_BACKEND_HOST=0.0.0.0
    restart: unless-stopped

  web:
    environment:
      - ROTKI_API_URL=http://rotki:5042

volumes:
  rotki-data:
```

## Security

### Authentication Flow

1. User enters Rotki password in frontend
2. Password sent to `/api/v1/rotki/connect` with OAuth token
3. Backend calls Rotki API to authenticate
4. On success, encrypted password stored in Sure for future sessions

### Security Measures

- **HTTPS Support**: Automatically enabled when URL uses `https://`
- **Timeouts**: Prevents hanging connections (10s connect, 30s read)
- **Error Handling**: Custom exception class prevents stack trace leakage
- **XSS Protection**: Frontend sanitizes all user data before rendering
- **Scope Enforcement**: API endpoints require proper OAuth scopes
- **Rate Limiting**: Inherits existing Rack Attack configuration

## Error Handling

| Error Type | HTTP Status | User Message |
|------------|-------------|---------------|
| RotkiServiceError (API failure) | 503 | "Unable to fetch balances from Rotki" |
| Invalid Rotki credentials | 422 | "Unable to connect to Rotki. Please check your password." |
| Missing/invalid scope | 403 | (OAuth scope error) |
| Authentication required | 401 | (OAuth auth error) |

## Testing

### Unit Tests

```bash
# RotkiService tests
bin/rails test test/services/rotki_service_test.rb

# Mapper tests
bin/rails test test/services/rotki/mapper_test.rb

# Balance cache tests
bin/rails test test/services/rotki/balance_cache_test.rb
```

### Integration Tests

```bash
# Controller tests
bin/rails test test/controllers/api/v1/rotki_controller_test.rb

# Full integration test
bin/rails test test/integration/rotki_integration_test.rb
```

### Mocking

Tests use Mocha's `stubs` and `expects` for mocking:

```ruby
RotkiService.any_instance.stubs(:balances).returns({
  "result" => { "total" => { "ETH" => { "amount" => "1.0", "usd_value" => "3000.0" } } },
  "message" => ""
})
```

## Data Flow

### Connecting a Rotki Account

```
User Input (Password)
       │
       ▼
POST /api/v1/rotki/connect
       │
       ▼
RotkiController#connect
       │
       ▼
User#authenticate_with_rotki!
       │
       ▼
RotkiService#login(email, password)
       │
       ▼
Rotki API (POST /api/1/users/{username})
       │
       ▼
Encrypt & store password
       │
       ▼
Return { status: "connected" }
```

### Fetching Balances

```
GET /api/v1/rotki/balances
       │
       ▼
RotkiController#balances
       │
       ▼
Rotki::BalanceCache#get_balances(user)
       │
       ├─▶ Cache hit ──▶ Return cached data
       │
       └─▶ Cache miss ──▶ RotkiService#balances
                               │
                               ▼
                         Rotki API (GET /api/1/balances)
                               │
                               ▼
                         Cache response
                               │
                               ▼
                         Rotki::Mapper#map_balances
                               │
                               ▼
                         Return mapped data
```

## Monitoring

### Logging

All Rotki operations are logged with context:

```ruby
Rails.logger.error "RotkiController#balances error: #{e.message}"
```

### Health Checks

Consider adding a health check endpoint:

```ruby
def health
  response = RotkiService.new.periodic_data
  render json: { status: "healthy", data: response }
end
```

---

# Potential Future Improvements

## High Priority

### 1. Two-Way Sync (Write Support)

**Current:** One-way sync from Rotki to Sure (read-only)

**Enhancement:** Allow editing crypto transactions in Sure and syncing back to Rotki

```ruby
# Example: Sync transaction to Rotki
def sync_transaction_to_rotki(transaction)
  post("/api/1/transactions", {
    tx_hash: transaction.hash,
    block_number: transaction.block_number,
    # ... other fields
  })
end
```

### 2. Automatic Refresh Job

**Current:** Manual refresh only

**Enhancement:** Background job for periodic balance updates

```ruby
# app/jobs/rotki_sync_job.rb
class RotkiSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    return unless user.rotki_connected?

    Rotki::BalanceCache.new.get_balances(user, force_refresh: true)
  end
end

# Schedule in config/schedule.rb
every 15.minutes do
  job RotkiSyncJob
end
```

### 3. Multi-Currency Support

**Current:** USD-only conversion

**Enhancement:** Support multiple fiat currencies

```ruby
def calculate_net_worth(response, currency: "USD")
  # Use exchange rates to convert to desired currency
  response["total"].sum do |asset, data|
    value = parse_usd_value(data["usd_value"]) || 0
    convert_currency(value, from: "USD", to: currency)
  end
end
```

### 4. WebSocket Updates

**Current:** Polling-based (cache refresh)

**Enhancement:** Real-time updates via ActionCable

```ruby
# Broadcast balance update after sync
ActionCable.server.broadcast "rotki:#{user.id}", {
  net_worth: new_total,
  balances: mapped_balances
}
```

## Medium Priority

### 5. Offline Mode Support

Cache balance snapshots for offline viewing

```ruby
def get_balances(user, force_refresh: false)
  cache_key = "rotki_balances:#{user.id}"
  
  Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
    fetch_from_rotki(user)
  end
rescue RotkiServiceError
  # Return stale cache on failure
  Rails.cache.read(cache_key) || {}
end
```

### 6. Exchange-Specific Balance Breakdown

Show balances grouped by exchange

```ruby
# Fetch and group by exchange
def balances_by_exchange
  response = @service.exchange_balances
  mapper = Rotki::Mapper.new
  
  response["result"].each_with_object({}) do |(exchange, balances), hash|
    hash[exchange] = balances.map { |b| mapper.map_to_net_worth(b) }
  end
end
```

### 7. Historical Net Worth Tracking

Store historical snapshots for charts/reports

```ruby
# app/models/rotki_snapshot.rb
class RotkiSnapshot < ApplicationRecord
  belongs_to :user
  
  # Store: net_worth, balances_json, snapshot_at
end

# After each balance fetch
def record_snapshot(user, balances)
  RotkiSnapshot.create!(
    user: user,
    net_worth: mapper.calculate_net_worth(balances),
    balances_json: balances.to_json,
    snapshot_at: Time.current
  )
end
```

### 8. Transaction Import

Import transactions from Rotki

```ruby
def import_transactions(user, start_date: nil, end_date: nil)
  params = { from_timestamp: start_date, to_timestamp: end_date }
  response = @service.transactions(params)
  
  response["result"].each do |tx|
    # Create Transaction record in Sure
    Transaction.create!(
      user: user,
      amount: tx["amount"],
      # ... map other fields
    )
  end
end
```

### 9. Connection Status Monitoring

Track Rotki connection health

```ruby
# Add to User model
def rotki_connected?
  rotki_encrypted_password.present? && rotki_last_sync_at.present?
end

def rotki_health_check
  RotkiService.new.periodic_data
  update(rotki_last_health_check_at: Time.current)
rescue RotkiServiceError
  # Handle connection failure
end
```

## Low Priority

### 10. Support for Rotki Premium Features

Handle premium-only API endpoints

```ruby
def premium_balances
  raise RotkiServiceError, "Premium feature" unless premium?
  
  get("/api/1/balances/advanced")
end
```

### 11. DeFi Protocol Integration

Track DeFi positions

```ruby
def defi_positions
  get("/api/1/balances/defi")
end

# Track lending, staking, LP positions
```

### 12. NFT Support

Import NFT holdings

```ruby
def nfts
  get("/api/1/nfts")
end
```

### 13. Tax Report Generation

Generate tax reports using Rotki data

```ruby
def tax_report(year:)
  get("/api/1/tax_report", { year: year })
end
```

### 14. Cost Basis Tracking

Import cost basis data for capital gains

```ruby
def cost_basis
  get("/api/1/cost_basis")
end
```

### 15. Multi-Instance Support

Support connecting multiple Rotki instances

```ruby
# User has many Rotki connections
class User < ApplicationRecord
  has_many :rotki_connections
end

class RotkiConnection < ApplicationRecord
  belongs_to :user
  # name, api_url, encrypted_password
end
```

---

## Implementation Priority Recommendation

1. **Immediate**: Background sync job (#2) - improves data freshness
2. **This Quarter**: Historical tracking (#7) - enables net worth charts
3. **Next Quarter**: Transaction import (#8) - fills data gaps
4. **Later**: Two-way sync (#1) - full integration

---

*Generated for Sure v2.x - Rotki Integration*
