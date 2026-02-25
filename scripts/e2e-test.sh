#!/bin/bash

# E2E Test Suite using agent-browser
# This script simulates core user journeys using Vercel's headless browser CLI

set -e

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000}"
TEST_USER_EMAIL="${TEST_USER_EMAIL:-test@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-testpassword123}"
TIMEOUT=30000

echo "========================================="
echo "SureCrypto E2E Test Suite"
echo "========================================="
echo "Base URL: $BASE_URL"
echo ""

# Check if agent-browser is installed
if ! command -v agent-browser &> /dev/null; then
    echo "Installing agent-browser..."
    npm install -g agent-browser
    agent-browser install --with-deps
fi

# Function to run agent-browser commands
run_agent() {
    local action="$1"
    local url="$2"
    local options="${3:-}"
    
    echo "Running: $action on $url"
    agent-browser "$action" "$url" $options --timeout=$TIMEOUT
}

# Test 1: Homepage accessibility
echo ""
echo "Test 1: Testing homepage accessibility..."
run_agent "navigate" "$BASE_URL" || {
    echo "❌ FAILED: Homepage not accessible"
    exit 1
}
echo "✓ Homepage is accessible"

# Test 2: Login page
echo ""
echo "Test 2: Testing login page..."
run_agent "navigate" "$BASE_URL/session/new" || {
    echo "❌ FAILED: Login page not accessible"
    exit 1
}
echo "✓ Login page is accessible"

# Test 3: Registration page
echo ""
echo "Test 3: Testing registration page..."
run_agent "navigate" "$BASE_URL/users/new" || {
    echo "❌ FAILED: Registration page not accessible"
    exit 1
}
echo "✓ Registration page is accessible"

# Test 4: API health check
echo ""
echo "Test 4: Testing API health endpoint..."
run_agent "navigate" "$BASE_URL/up" || {
    echo "❌ FAILED: Health endpoint not accessible"
    exit 1
}
echo "✓ API health endpoint is accessible"

# Test 5: Check for security headers
echo ""
echo "Test 5: Testing security headers..."
HEADERS=$(curl -sI "$BASE_URL" 2>/dev/null | head -20)

if echo "$HEADERS" | grep -q "X-Frame-Options"; then
    echo "✓ X-Frame-Options header present"
else
    echo "⚠ Warning: X-Frame-Options header missing"
fi

if echo "$HEADERS" | grep -q "X-Content-Type-Options"; then
    echo "✓ X-Content-Type-Options header present"
else
    echo "⚠ Warning: X-Content-Type-Options header missing"
fi

if echo "$HEADERS" | grep -q "X-XSS-Protection\|Content-Security-Policy"; then
    echo "✓ XSS protection header present"
else
    echo "⚠ Warning: XSS protection header missing"
fi

# Test 6: Test login form interaction (if credentials provided)
echo ""
echo "Test 6: Testing login form..."
if [ -n "$TEST_USER_EMAIL" ] && [ -n "$TEST_USER_PASSWORD" ]; then
    # Use agent-browser to interact with login form
    agent-browser navigate "$BASE_URL/session/new" \
        --eval="
            document.querySelector('input[name=\"email\"]').value = '$TEST_USER_EMAIL';
            document.querySelector('input[name=\"password\"]').value = '$TEST_USER_PASSWORD';
            document.querySelector('form').submit();
        " --wait-for="title" --timeout=$TIMEOUT || {
        echo "⚠ Login form interaction failed (may be expected in CI without valid users)"
    }
else
    echo "⚠ Skipped: No test credentials provided"
fi

# Test 7: Test static assets
echo ""
echo "Test 7: Testing static assets..."
STATIC_ASSETS=(
    "/assets/application.css"
    "/assets/application.js"
)

for asset in "${STATIC_ASSETS[@]}"; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$asset" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "304" ]; then
        echo "✓ Asset accessible: $asset"
    else
        echo "⚠ Asset not found or error ($HTTP_STATUS): $asset"
    fi
done

# Test 8: Test API endpoints without auth (should return 401)
echo ""
echo "Test 8: Testing API authentication..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/accounts" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "401" ]; then
    echo "✓ API returns 401 for unauthenticated requests"
else
    echo "⚠ API returned $HTTP_STATUS (expected 401)"
fi

# Test 9: Check for common vulnerabilities - exposed git directory
echo ""
echo "Test 9: Testing for exposed sensitive directories..."
SENSITIVE_PATHS=(
    "/.git"
    "/.env"
    "/config/database.yml"
    "/Gemfile.lock"
)

EXPOSED_COUNT=0
for path in "${SENSITIVE_PATHS[@]}"; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$path" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "❌ EXPOSED: $path is accessible (security risk!)"
        EXPOSED_COUNT=$((EXPOSED_COUNT + 1))
    else
        echo "✓ Protected: $path"
    fi
done

if [ $EXPOSED_COUNT -gt 0 ]; then
    echo ""
    echo "⚠ WARNING: $EXPOSED_COUNT sensitive paths are exposed!"
fi

# Test 10: Response time check
echo ""
echo "Test 10: Testing response times..."
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$BASE_URL" 2>/dev/null || echo "999")
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc 2>/dev/null || echo "0")

if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l 2>/dev/null || echo "0") )); then
    echo "✓ Homepage loads in ${RESPONSE_TIME}s (acceptable)"
else
    echo "⚠ Homepage load time: ${RESPONSE_TIME}s (consider optimizing)"
fi

echo ""
echo "========================================="
echo "E2E Test Suite Complete"
echo "========================================="
echo ""

exit 0