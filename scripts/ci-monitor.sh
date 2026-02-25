#!/bin/bash

# Automated CI/CD Fix Loop
# Monitors GitHub Actions, detects failures, analyzes logs, and provides fix instructions

set -e

REPO="${REPO:-moltenglue/sure-crypto}"
WORKFLOW_FILE="${WORKFLOW_FILE:-ci-test-pipeline.yml}"
MAX_ITERATIONS="${MAX_ITERATIONS:-20}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

iteration=1
last_run_id=""

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to analyze error patterns
analyze_error() {
    local logs="$1"
    local fixes=()
    
    # Pattern 1: Enum validation errors
    if echo "$logs" | grep -q "Undeclared attribute type for enum"; then
        log_error "Found: Enum validation error"
        log_info "Cause: Migration loading model before enum column exists"
        log_info "Fix: Use SQL directly in migrations instead of ActiveRecord models"
        log_info "Example: execute \"UPDATE users SET role = 'admin' WHERE role IS NULL\""
        fixes+=("migration-enum")
    fi
    
    # Pattern 2: PostgreSQL enum errors
    if echo "$logs" | grep -q "PG::InvalidTextRepresentation.*enum"; then
        log_error "Found: PostgreSQL enum value error"
        log_info "Cause: Comparing enum column with invalid value (e.g., empty string)"
        log_info "Fix: Remove empty string checks for enum columns, only check IS NULL"
        fixes+=("sql-enum")
    fi
    
    # Pattern 3: Syntax errors
    if echo "$logs" | grep -q "syntax error"; then
        log_error "Found: Ruby syntax error"
        log_info "Fix: Check the file for missing/extra 'end' keywords or other syntax issues"
        log_info "Check: ruby -c <filename>"
        fixes+=("syntax")
    fi
    
    # Pattern 4: Database connection
    if echo "$logs" | grep -q "PG::UndefinedTable\|PG::ConnectionBad"; then
        log_error "Found: Database connection/table error"
        log_info "Fix: Check migration order and database service health"
        fixes+=("database")
    fi
    
    # Pattern 5: Undefined method
    if echo "$logs" | grep -q "undefined method"; then
        log_error "Found: Undefined method error"
        log_info "Fix: Check for typos or missing method definitions"
        fixes+=("method")
    fi
    
    # Pattern 6: Missing require
    if echo "$logs" | grep -q "uninitialized constant"; then
        log_error "Found: Uninitialized constant"
        log_info "Fix: Add missing require statement or check gem is loaded"
        fixes+=("constant")
    fi
    
    # Pattern 7: External service connection
    if echo "$logs" | grep -q "ConnectionError\|unable to connect"; then
        log_warn "Found: External service connection error"
        log_info "Note: Tests requiring external services may need mocking in CI"
        fixes+=("external-service")
    fi
    
    # Pattern 8: Test failures (not errors)
    if echo "$logs" | grep -q "Failure:"; then
        log_warn "Found: Test assertions failing"
        log_info "Check: Review test expectations vs. actual behavior"
        fixes+=("test-failure")
    fi
    
    if [ ${#fixes[@]} -eq 0 ]; then
        log_warn "No known error pattern matched"
        return 1
    fi
    
    return 0
}

# Main monitoring loop
while [ $iteration -le $MAX_ITERATIONS ]; do
    clear
    echo "========================================"
    echo "  Automated CI/CD Fix Loop"
    echo "  Iteration: $iteration/$MAX_ITERATIONS"
    echo "  Repository: $REPO"
    echo "========================================"
    echo ""
    
    # Get latest workflow run
    log_info "Fetching latest workflow run..."
    
    RUN_INFO=$(gh run list --repo "$REPO" --workflow "$WORKFLOW_FILE" --limit 1 --json databaseId,status,conclusion,headBranch,event,createdAt 2>/dev/null || echo "[]")
    
    if [ "$RUN_INFO" = "[]" ]; then
        log_warn "No workflow runs found. Waiting..."
        sleep $CHECK_INTERVAL
        iteration=$((iteration + 1))
        continue
    fi
    
    # Extract run details
    RUN_ID=$(echo "$RUN_INFO" | grep -o '"databaseId":[0-9]*' | head -1 | cut -d: -f2)
    STATUS=$(echo "$RUN_INFO" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    CONCLUSION=$(echo "$RUN_INFO" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
    BRANCH=$(echo "$RUN_INFO" | grep -o '"headBranch":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo ""
    echo "Latest Run Details:"
    echo "  Run ID: $RUN_ID"
    echo "  Branch: $BRANCH"
    echo "  Status: $STATUS"
    echo "  Conclusion: ${CONCLUSION:-N/A}"
    echo ""
    
    # Check if this is a new run
    if [ "$RUN_ID" = "$last_run_id" ] && [ "$STATUS" = "completed" ]; then
        log_info "No new runs detected. Waiting..."
        sleep $CHECK_INTERVAL
        continue
    fi
    
    last_run_id="$RUN_ID"
    
    # Wait for completion
    if [ "$STATUS" != "completed" ]; then
        log_info "Workflow is running. Monitoring progress..."
        
        while [ "$STATUS" != "completed" ]; do
            sleep $CHECK_INTERVAL
            STATUS=$(gh run view "$RUN_ID" --repo "$REPO" --json status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            echo -n "."
        done
        echo ""
        
        # Get final conclusion
        CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO" --json conclusion 2>/dev/null | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4)
    fi
    
    echo ""
    
    # Check success
    if [ "$CONCLUSION" = "success" ]; then
        log_success "🎉 WORKFLOW SUCCEEDED! All tests passed."
        echo ""
        echo "Summary:"
        echo "  Total Iterations: $iteration"
        echo "  Final Run ID: $RUN_ID"
        echo "  View Results: https://github.com/$REPO/actions/runs/$RUN_ID"
        echo ""
        exit 0
    fi
    
    # Workflow failed - analyze
    log_error "❌ WORKFLOW FAILED"
    echo ""
    
    # Get failed jobs
    log_info "Analyzing failed jobs..."
    FAILED_JOBS=$(gh run view "$RUN_ID" --repo "$REPO" --json jobs 2>/dev/null)
    
    # Extract job IDs with failures
    echo "$FAILED_JOBS" | grep -o '"databaseId":[0-9]*' | cut -d: -f2 > /tmp/job_ids.txt
    
    error_found=false
    
    while read -r JOB_ID; do
        if [ -z "$JOB_ID" ]; then continue; fi
        
        # Get job name
        JOB_NAME=$(echo "$FAILED_JOBS" | grep -B 5 "\"databaseId\":$JOB_ID" | grep '"name"' | head -1 | cut -d'"' -f4)
        JOB_STATUS=$(echo "$FAILED_JOBS" | grep -A 10 "\"databaseId\":$JOB_ID" | grep '"conclusion"' | head -1 | cut -d'"' -f4)
        
        if [ "$JOB_STATUS" = "failure" ]; then
            log_error "Failed Job: $JOB_NAME (ID: $JOB_ID)"
            
            # Get logs
            LOGS=$(gh run view --log-failed --job="$JOB_ID" --repo "$REPO" 2>&1 || echo "Failed to fetch logs")
            
            # Analyze errors
            if analyze_error "$LOGS"; then
                error_found=true
            fi
            
            # Save logs for manual review
            echo "$LOGS" > "/tmp/failed_job_${JOB_ID}.log"
            log_info "Full logs saved to: /tmp/failed_job_${JOB_ID}.log"
            echo ""
        fi
    done < /tmp/job_ids.txt
    
    if [ "$error_found" = false ]; then
        log_warn "Could not automatically identify error pattern"
        log_info "View full logs at: https://github.com/$REPO/actions/runs/$RUN_ID"
    fi
    
    echo ""
    echo "========================================"
    log_info "Next steps:"
    echo "1. Review the error analysis above"
    echo "2. Make necessary fixes to your code"
    echo "3. Commit and push to trigger a new run"
    echo "4. This script will automatically detect the new run"
    echo ""
    log_info "Waiting for next run or $CHECK_INTERVAL seconds..."
    echo "Press Ctrl+C to exit"
    echo "========================================"
    
    sleep $CHECK_INTERVAL
    iteration=$((iteration + 1))
done

echo ""
log_error "Maximum iterations ($MAX_ITERATIONS) reached"
log_warn "Tests did not pass automatically. Manual intervention may be required."
log_info "View latest run: https://github.com/$REPO/actions"
exit 1