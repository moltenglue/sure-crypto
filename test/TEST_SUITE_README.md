# SureCrypto Automated Test Suite

This directory contains a comprehensive automated test suite covering Integration, E2E, Security, and Performance testing.

## Test Suite Overview

### 1. Integration Tests (`test/integration/`)

Integration tests verify interactions between application components and external systems.

#### New Tests Created:
- **`api_integration_test.rb`** - Tests API authentication, CRUD operations, and rate limiting
- **`auth_flow_integration_test.rb`** - Tests login/logout, registration, and session management
- **`transaction_flow_integration_test.rb`** - Tests transaction CRUD operations and search
- **`account_management_integration_test.rb`** - Tests account creation, updates, and sync
- **`security_test.rb`** - Comprehensive security tests (SQL injection, XSS, auth)
- **`brakeman_security_test.rb`** - Automated Brakeman static analysis integration

#### Existing Tests:
- `cors_test.rb` - CORS policy verification
- `oauth_basic_test.rb` - OAuth flow testing
- `oauth_mobile_test.rb` - Mobile OAuth testing
- `rack_attack_test.rb` - Rate limiting tests
- `rotki_integration_test.rb` - Rotki integration tests
- `rotki_full_flow_test.rb` - Full Rotki workflow tests

**Run Integration Tests:**
```bash
bin/rails test test/integration/
```

### 2. E2E Tests (`scripts/e2e-test.sh`)

End-to-end tests using `agent-browser` (Vercel's headless browser CLI) to simulate real user journeys.

#### Test Coverage:
1. Homepage accessibility
2. Login page functionality
3. Registration page
4. API health endpoint
5. Security headers verification
6. Login form interaction (with credentials)
7. Static assets loading
8. API authentication (401 checks)
9. Sensitive path exposure checks
10. Response time validation

**Prerequisites:**
```bash
npm install -g agent-browser
agent-browser install --with-deps
```

**Run E2E Tests:**
```bash
# Set environment variables (optional)
export BASE_URL=http://localhost:3000
export TEST_USER_EMAIL=test@example.com
export TEST_USER_PASSWORD=password

# Run tests
./scripts/e2e-test.sh
```

### 3. Performance Tests (`performance/`)

Load and stress testing using k6 (industry-standard load testing tool).

#### Test Scripts:
- **`smoke_test.js`** - Quick sanity check (1 VU, 1 minute)
- **`load_test.js`** - Gradual load increase (up to 20 VUs)
- **`stress_test.js`** - Spike testing (up to 150 VUs)

**Prerequisites:**
```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Run Performance Tests:**
```bash
# Smoke test
k6 run performance/smoke_test.js

# Load test
k6 run performance/load_test.js

# Stress test
k6 run performance/stress_test.js

# With custom base URL
BASE_URL=http://staging.example.com k6 run performance/load_test.js
```

### 4. Security Tests

Security tests are integrated into the test suite and include:

#### SQL Injection Protection:
- Malicious input in search parameters
- Malicious account names
- Transaction name sanitization

#### XSS Prevention:
- Script tag injection attempts
- Event handler injection
- HTML tag sanitization

#### Authorization Checks:
- Cross-user data access prevention
- Transaction modification restrictions
- Mass assignment protection

#### Rate Limiting:
- Login attempt throttling
- API rate limiting

#### Static Analysis:
- Brakeman security scan
- Vulnerable dependency check

**Run Security Tests:**
```bash
# Ruby security tests
bin/rails test test/integration/security_test.rb

# Brakeman static analysis
bin/brakeman -q --no-pager

# Dependency audit
bundle exec bundle-audit check --update
```

## CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/ci-test-pipeline.yml`)

A comprehensive CI pipeline that runs all test suites sequentially:

#### Jobs:
1. **Setup** - Install dependencies and cache
2. **Lint & Security** - Rubocop, Brakeman, Biome, dependency audit
3. **Unit Tests** - Model, service, and job tests
4. **Integration Tests** - Controller and integration tests
5. **System Tests** - Capybara system tests
6. **E2E Tests** - agent-browser end-to-end tests
7. **Security Tests** - Security-focused integration tests
8. **Performance Tests** - k6 load testing
9. **Test Summary** - Aggregates all results

#### Features:
- PostgreSQL and Redis service containers
- Artifact upload for test results and screenshots
- Parallel job execution where possible
- Sequential dependency chain for test stages
- Configurable timeouts
- Test result aggregation

#### Trigger:
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
```

## Running All Tests Locally

### Full Test Suite:
```bash
# Start dependencies
docker-compose up -d postgres redis

# Setup database
bin/rails db:create db:migrate db:seed

# Run all Ruby tests
bin/rails test

# Run system tests
DISABLE_PARALLELIZATION=true bin/rails test:system

# Run E2E tests (requires server running)
./scripts/e2e-test.sh

# Run performance tests (requires server running)
k6 run performance/smoke_test.js
```

### With Coverage:
```bash
COVERAGE=true bin/rails test
```

## Test Data

Tests use fixtures located in `test/fixtures/`:
- Users and families
- Accounts and transactions
- API keys for testing

## Environment Variables

### Test-Specific:
- `RAILS_ENV=test` - Required for test environment
- `CI=true` - Enables CI-specific configurations
- `COVERAGE=true` - Enables SimpleCov coverage reporting
- `DISABLE_PARALLELIZATION=true` - Disables parallel test execution

### E2E Tests:
- `BASE_URL` - Target URL for E2E tests (default: http://localhost:3000)
- `TEST_USER_EMAIL` - Test user email for login tests
- `TEST_USER_PASSWORD` - Test user password

### Performance Tests:
- `BASE_URL` - Target URL for k6 tests (default: http://localhost:3000)

## Troubleshooting

### Common Issues:

1. **Database connection errors:**
   ```bash
   bin/rails db:create db:migrate
   ```

2. **Chrome/Chromium not found (System Tests):**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install google-chrome-stable
   
   # macOS
   brew install --cask google-chrome
   ```

3. **Agent-browser not found:**
   ```bash
   npm install -g agent-browser
   agent-browser install --with-deps
   ```

4. **k6 not found:**
   Follow installation instructions above for your OS.

## Maintenance

### Adding New Tests:

1. **Integration Tests:** Add to `test/integration/test_name_test.rb`
2. **E2E Tests:** Add scenarios to `scripts/e2e-test.sh`
3. **Performance Tests:** Create new `.js` files in `performance/`
4. **Security Tests:** Add to `test/integration/security_test.rb`

### CI/CD Updates:

Modify `.github/workflows/ci-test-pipeline.yml` to add new jobs or adjust existing ones.

## Contributing

When adding new features:
1. Write integration tests for API changes
2. Add E2E tests for user-facing features
3. Include security tests for authentication/authorization changes
4. Run performance tests for database-heavy operations
5. Ensure all tests pass in CI before merging
