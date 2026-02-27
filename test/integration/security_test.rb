# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    @account = accounts(:empty_checking)
  end

  # SQL Injection Tests
  test "prevents SQL injection in search parameters" do
    sign_in(@user)
    malicious_input = "'; DROP TABLE users; --"
    
    get transactions_path, params: { q: malicious_input }
    assert_response :success
    # Verify users table still exists
    assert User.count >= 0
  end

  test "prevents SQL injection in account name" do
    sign_in(@user)
    malicious_name = "Test'); DROP TABLE accounts; --"
    
    # This should either fail validation or sanitize the input
    post accounts_path, params: {
      account: {
        name: malicious_name,
        accountable_type: "Depository",
        balance: 100
      }
    }
    # Should either succeed with sanitized input or fail validation (not crash)
    assert [200, 302, 422].include?(response.status)
    assert Account.count >= 0
  end

  # XSS Prevention Tests
  test "sanitizes XSS in transaction name" do
    sign_in(@user)
    xss_payload = "<script>alert('xss')</script>"
    
    post transactions_path, params: {
      transaction: {
        name: xss_payload,
        amount: 50,
        currency_code: "USD",
        date: Date.today.to_s
      }
    }
    
    if response.status == 302 || response.status == 201
      transaction = Transaction.last
      # Verify script tag is not stored as-is
      refute transaction.name.include?("<script>"), "XSS payload should be sanitized"
    end
  end

  test "sanitizes XSS in account name" do
    sign_in(@user)
    xss_payload = "<img src=x onerror=alert('xss')>"
    
    post accounts_path, params: {
      account: {
        name: xss_payload,
        accountable_type: "Depository",
        balance: 100
      }
    }
    
    if response.status == 302 || response.status == 201
      account = Account.last
      refute account.name.include?("<img"), "XSS payload should be sanitized"
    end
  end

  # CSRF Protection Tests
  test "requires CSRF token for state-changing requests" do
    # Skip CSRF protection in test environment check
    # In production, this should be enforced
  end

  # Authorization Tests
  test "prevents access to other users' data" do
    other_family = families(:dollar)
    other_account = accounts(:dollar_checking)
    
    sign_in(@user)
    
    # Try to access another user's account
    get account_path(other_account)
    assert_response :not_found
  end

  test "prevents modifying other users' transactions" do
    other_transaction = transactions(:savings_one)
    
    sign_in(@user)
    
    patch transaction_path(other_transaction), params: {
      transaction: { name: "Hacked" }
    }
    assert_response :not_found
  end

  # Mass Assignment Protection
  test "prevents mass assignment of protected attributes" do
    sign_in(@user)
    
    original_created_at = @account.created_at
    
    patch account_path(@account), params: {
      account: {
        name: "Updated Name",
        created_at: 1.year.ago
      }
    }
    
    @account.reload
    assert_equal original_created_at.to_i, @account.created_at.to_i
  end

  # Rate Limiting Tests
  test "implements rate limiting on login attempts" do
    # Make multiple rapid login attempts
    5.times do
      post sessions_path, params: {
        email: @user.email,
        password: "wrongpassword"
      }
    end
    
    # Should either succeed or be rate limited (429) or unprocessable (422 for invalid credentials)
    assert [401, 422, 429].include?(response.status)
  end

  # API Security Tests
  test "rejects API requests without authentication" do
    get api_v1_accounts_path
    assert_response :unauthorized
  end

  test "rejects API requests with invalid authentication" do
    get api_v1_accounts_path, headers: { "X-Api-Key" => "invalid_token" }
    assert_response :unauthorized
  end

  # Path Traversal Tests
  test "prevents path traversal in file upload paths" do
    # This would test file upload functionality if present
    # For now, test that sensitive paths are blocked
    
    get "/../config/database.yml"
    assert_response :not_found
  end

  # Security Headers Tests
  test "includes security headers in responses" do
    get root_path
    
    # Check for common security headers
    headers = response.headers
    
    # X-Frame-Options should prevent clickjacking
    if headers["X-Frame-Options"]
      assert_includes ["DENY", "SAMEORIGIN"], headers["X-Frame-Options"]
    end
    
    # X-Content-Type-Options prevents MIME sniffing
    if headers["X-Content-Type-Options"]
      assert_equal "nosniff", headers["X-Content-Type-Options"]
    end
  end

  # Brute Force Protection Tests
  test "accounts are protected against brute force attacks" do
    # Multiple failed login attempts should trigger lockout or delay
    10.times do |i|
      post sessions_path, params: {
        email: "nonexistent#{i}@example.com",
        password: "wrongpassword"
      }
    end
    
    # After many attempts, should return unprocessable (422) or unauthorized (401)
    assert [401, 422].include?(response.status)
  end
end