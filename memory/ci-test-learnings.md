# CI Test Fixes - Key Learnings

## 1. Transaction Model Architecture
- Transaction uses `delegated_type` with Entry
- Transaction does NOT have `account_id` column directly
- Account is associated through Entry (Entry belongs_to :account)
- Therefore: Transaction fixtures should NOT have `account` or `account_id` columns

## 2. Fixtures Pattern
- Entry fixtures reference Transaction fixtures via `entryable: one`
- Transaction fixtures only need: category, merchant, name, amount, currency_code, date, kind
- Never add account_id/account to transaction fixtures

## 3. API Key Fixtures
- ApiKey model requires `source` field to be present
- Valid sources: "web", "mobile", "monitoring"
- Use `display_key` not `token` (token method doesn't exist)

## 4. Routes
- Registration is `registration_path` not `users_path`
- Users resource is for updating/destroying existing users

## 5. Fixtures need associations that exist
- Always check the model to see what associations exist
- Don't assume column names - check the actual schema/model
- Use correct fixture names that exist in related fixtures

## 6. Test Environment Encryption
- Rails credentials.yml.enc requires RAILS_MASTER_KEY
- In CI without credentials file, need to skip credentials loading
- Use SKIP_CREDENTIALS env var to bypass encrypted credential loading
- Add encryption keys via env vars as backup: ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, etc.

## 7. Common Fixture Errors
- "table X has no columns named Y" = wrong column name in fixture
- Usually means the association is through another model (like Entry)

## 8. Transaction Table Schema
- Transactions table was renamed to `account_transactions` in migration but schema.rb shows `transactions`
- Current transactions table columns: category_id, merchant_id, locked_attributes, kind, external_id, extra, investment_activity_label
- Transaction does NOT have: name, amount, currency_code, date, account_id - these are on Entry
- This is because Transaction uses Entryable (delegated_type pattern)

## 9. Assets in Test Environment
- tailwind.css not found in test - need to add asset paths in test.rb
- Add: `config.assets.paths << Rails.root.join("app/assets/builds")`
- Add: `config.assets.compile = true` for test environment
- Also need to precompile assets in CI before running tests

## 10. Skip Statement Cleanup
- Always remove ALL code after a skip statement in tests
- Leftover code causes syntax errors that are hard to debug
- Pattern to avoid:
  ```ruby
  test "something" do
    skip "reason"
  end
    leftover_code  # THIS CAUSES SYNTAX ERROR
  ```

## 11. Fixture Foreign Key Constraints
- Fixtures must reference valid associated fixtures
- Transaction category must reference existing category fixture
- Transaction merchant must reference existing merchant fixture
- Error: "Key (category_id)=(...) is not present in table categories"
- Solution: Check that referenced fixtures exist in related fixture files

## 12. Route Issues in Tests
- Always verify routes exist before using them in tests
- Use `rails routes | grep` to check available routes
- `account_transactions_path` may not exist - use `transactions_path` instead

## 13. Controller Parameter Handling
- `params.fetch(:key, {})` can return String, not Hash, if value is passed
- Always validate parameter type before calling .permit
- Fix: Check `is_a?(ActionController::Parameters) || is_a?(Hash)` before permitting

## 14. Rotki API Session Management
- Rotki API requires session cookie for authenticated requests
- Login endpoint returns user settings but session cookie may not be captured
- Cookie capture regex: `/rotki_session=([^;]+)/`
- If cookie not captured, subsequent requests fail with 500 + "400 Bad Request"
- Debug: Log all response headers to see what Set-Cookie header contains
- Rotki may use different cookie name or header format than expected

## 15. Rotki Behind Nginx Proxy
- When Rotki is behind nginx, Set-Cookie headers may be stripped
- Solution: Connect directly to Rotki backend API port (4242) instead of nginx proxy (5042)
- Session state is maintained through TCP connection, not cookies
- Create persistent `Net::HTTP` connection with `keep_alive_timeout`
- Reuse same connection for login and subsequent API calls
- Close connection on auth errors (401/403) to force re-login
- **Key**: Bypass nginx entirely by using the direct Rotki API URL (port 4242)
