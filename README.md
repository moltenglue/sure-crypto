<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.4+-ruby.svg" alt="Ruby">
  <img src="https://img.shields.io/badge/Rails-8.0-rails.svg" alt="Rails">
  <img src="https://img.shields.io/badge/Docker-Ready-blue.svg" alt="Docker">
  <img src="https://img.shields.io/badge/License-AGPLv3-green.svg" alt="License">
</p>

# Sure Crypto - Rotki Integration

A community fork of [Sure](https://github.com/we-promise/sure) with integrated **Rotki** cryptocurrency portfolio tracking.

> This fork adds native Rotki integration to Sure, giving you a unified view of your entire financial portfolio including crypto holdings.

## Why Rotki?

**Rotki** is a free, open-source, self-hosted portfolio tracker, accounting, and analytics tool that protects your privacy.

| Feature | Rotki | Typical Paid Tools |
|---------|-------|-------------------|
| **Privacy** | 🔒 Self-hosted | ☁️ Cloud-only |
| **Cost** | 🆓 Free forever | 💰 $50-200+/year |
| **Exchanges** | 🔗 80+ supported | Varies |
| **Blockchains** | ⛓️ 30+ supported | Limited |
| **DeFi** | 📈 Native support | Premium only |

Rotki is the gold standard for self-hosted crypto tracking. By integrating with Sure, you get:
- **Unified Dashboard** - Crypto + bank accounts + investments in one view
- **Net Worth Tracking** - Complete financial picture
- **Privacy First** - Your crypto data stays on your server

---

## Quick Start

```bash
# Clone and start
git clone https://github.com/moltenglue/sure-crypto.git
cd sure-crypto
docker-compose -f compose.example.yml -f compose.rotki.yml up -d
```

Visit:
- **Sure**: http://localhost:3000 (create account)
- **Rotki**: http://localhost:5042 (create account)

### Connect Rotki

1. Open Sure → Settings → Accounts
2. Find Rotki in account sources
3. Enter your Rotki password
4. Click Connect

Your crypto balances now appear in your net worth!

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Sure (Rails)                           │
│  ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │ RotkiController │───▶│ Rotki::BalanceCache         │  │
│  │ (API Endpoints) │    │ (Rails.cache, 5-min TTL)    │  │
│  └────────┬────────┘    └─────────────┬───────────────┘  │
│           │                            │                   │
│           ▼                            ▼                   │
│  ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │ Rotki::Mapper   │◀───│ RotkiService               │  │
│  │ (Transform)     │    │ (HTTP Client)              │  │
│  └─────────────────┘    └─────────────┬───────────────┘  │
└────────────────────────────────────────┼──────────────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   Rotki Instance     │
                              │   (Python Backend)  │
                              │   • 80+ Exchanges   │
                              │   • 30+ Blockchains │
                              │   • DeFi Protocols  │
                              └──────────────────────┘
```

### Components

| File | Purpose |
|------|---------|
| `app/services/rotki_service.rb` | HTTP client for Rotki API |
| `app/services/rotki/mapper.rb` | Transform Rotki data → Sure format |
| `app/services/rotki/balance_cache.rb` | Cache balances (5-min TTL) |
| `app/controllers/api/v1/rotki_controller.rb` | REST API endpoints |
| `app/javascript/controllers/rotki_controller.js` | Frontend UI |

---

## Docker Compose

### Full Configuration

```yaml
# compose.yml
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: sure
      POSTGRES_PASSWORD: your_password
      POSTGRES_DB: sure_production
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sure"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

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
    build: .
    ports:
      - "3000:3000"
    volumes:
      - uploads:/rails/storage
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=your_secret
      - DATABASE_URL=postgresql://sure:your_password@db:5432/sure_production
      - REDIS_URL=redis://redis:6379/1
      - ROTKI_API_URL=http://rotki:5042
    depends_on:
      db:
        condition: service_healthy

  worker:
    build: .
    command: bundle exec sidekiq
    volumes:
      - uploads:/rails/storage
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=your_secret
      - DATABASE_URL=postgresql://sure:your_password@db:5432/sure_production
      - REDIS_URL=redis://redis:6379/1
    depends_on:
      db:
        condition: service_healthy

volumes:
  postgres-data:
  redis-data:
  rotki-data:
  uploads:
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ROTKI_API_URL` | Yes | Rotki API (e.g., `http://rotki:5042`) |
| `SECRET_KEY_BASE` | Yes | Generate with `rails secret` |
| `DATABASE_URL` | Yes | PostgreSQL connection string |

---

## Portainer Deployment

Deploy easily using [Portainer](https://www.portainer.io/) - a web-based container management UI.

### 1. Install Portainer

```bash
# Quick install
docker volume create portainer_data
docker run -d -p 9000:9000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
```

Access Portainer at: https://localhost:9443

### 2. Create Stack

In Portainer UI:
1. Go to **Stacks** → **Add stack**
2. Select **Git repository**
3. Repository URL: `https://github.com/moltenglue/sure-crypto`
4. Repository reference: `refs/heads/feature/rotki-integration`
5. Compose path: `compose.example.yml`
6. Click **Build** and then **Deploy the stack**

> **Note:** Use `feature/rotki-integration` branch - it contains the Rotki integration

### 3. Add Rotki

After deploying, edit the stack and add:
1. Go to **Stacks** → Your stack → **Edit**
2. In "Additional files", add: `compose.rotki.yml`
3. Click **Update stack**

### 4. Environment Variables

In Portainer, set these in the stack editor. Use **Advanced Mode** for all variables:

#### PostgreSQL (db)
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `POSTGRES_USER` | `sure_user` | Yes | Database username |
| `POSTGRES_PASSWORD` | — | Yes | Database password (set your own) |
| `POSTGRES_DB` | `sure_production` | No | Database name |

#### Redis
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `REDIS_URL` | `redis://redis:6379/1` | No | Redis connection string |

#### Rails Application (web/worker)
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `SECRET_KEY_BASE` | — | **Yes** | Generate with `rails secret` |
| `RAILS_ENV` | `production` | No | Rails environment |
| `RAILS_FORCE_SSL` | `false` | No | Force HTTPS |
| `RAILS_ASSUME_SSL` | `false` | No | Assume HTTPS terminated |
| `SELF_HOSTED` | `true` | No | Self-hosted mode |
| `DB_HOST` | `db` | No | Database hostname |
| `DB_PORT` | `5432` | No | Database port |
| `PORT` | `3000` | No | Application port |

#### Rotki Integration
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `ROTKI_API_URL` | `http://rotki:5042` | **Yes** | Rotki API endpoint |

#### Optional Features
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `OPENAI_ACCESS_TOKEN` | — | No | OpenAI API key for AI features |

#### Backup Service (optional)
| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `POSTGRES_HOST` | `db` | No | Database host for backups |
| `SCHEDULE` | `@daily` | No | Backup schedule (cron) |
| `BACKUP_KEEP_DAYS` | `7` | No | Daily backups to keep |
| `BACKUP_KEEP_WEEKS` | `4` | No | Weekly backups to keep |
| `BACKUP_KEEP_MONTHS` | `6` | No | Monthly backups to keep |

#### Quick Copy for Portainer

```
POSTGRES_USER=sure_user
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=sure_production
SECRET_KEY_BASE=$(rails secret)
RAILS_ENV=production
SELF_HOSTED=true
RAILS_FORCE_SSL=false
DB_HOST=db
DB_PORT=5439
REDIS_URL=redis://redis:6379/1
ROTKI_API_URL=http://rotki:5042
PORT=3000
# OPENAI_ACCESS_TOKEN=  # Optional
```

### 5. Access

| Service | URL | Port |
|---------|-----|------|
| Sure | http://localhost:3000 | 3000 |
| Rotki | http://localhost:5042 | 5042 |
| Portainer | https://localhost:9443 | 9443 |

---

## API

### Endpoints

```
GET  /api/v1/rotki/balances  # Fetch cached crypto balances (scope: read)
POST /api/v1/rotki/connect   # Connect Rotki account (scope: write)
```

### Example Response

```json
{
  "net_worth": 15250.50,
  "balances": {
    "total": [
      {"asset_symbol": "ETH", "quantity": "2.5", "converted_value": 7500.00},
      {"asset_symbol": "BTC", "quantity": "0.1", "converted_value": 6500.00}
    ],
    "blockchain": [...],
    "exchanges": [...]
  },
  "cached_at": "2026-02-24T15:30:00Z"
}
```

---

## Security

- Rotki password encrypted at rest
- OAuth scope enforcement (`read`/`write`)
- XSS protection in frontend
- HTTPS support when using `https://` URLs
- API timeouts (10s connect, 30s read)

---

## Development

```bash
# Setup
bin/setup
bin/dev

# Test
bin/rails test test/services/rotki/
bin/rails test test/integration/rotki_integration_test.rb
```

---

## License

AGPLv3 - See [LICENSE](./LICENSE).

A community fork of [Maybe Finance](https://github.com/maybe-finance/maybe)/[Sure](https://github.com/we-promise/sure) with Rotki integration.

---

## Links

- [Rotki Docs](https://docs.rotki.com)
- [Rotki Official Site](https://rotki.com)
- [Issues](https://github.com/moltenglue/sure-crypto/issues)
