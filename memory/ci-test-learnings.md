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
