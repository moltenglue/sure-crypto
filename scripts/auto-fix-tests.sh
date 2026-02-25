#!/bin/bash

# Automated test fix loop
# Monitors GitHub Actions workflow, reads logs on failure, and attempts fixes

REPO="moltenglue/sure-crypto"
WORKFLOW_FILE="ci-test-pipeline.yml"
MAX_ITERATIONS=10
SLEEP_TIME=180  # 3 minutes between checks

iteration=1

while [ $iteration -le $MAX_ITERATIONS ]; do
    echo "========================================="
    echo "Iteration $iteration of $MAX_ITERATIONS"
    echo "========================================="
    
    # Get the latest workflow run
    echo "Checking latest workflow run..."
    RUN_INFO=$(gh run list --repo $REPO --workflow $WORKFLOW_FILE --limit 1 --json databaseId,status,conclusion,headBranch,event 2>/dev/null)
    
    if [ -z "$RUN_INFO" ] || [ "$RUN_INFO" = "[]" ]; then
        echo "No workflow runs found. Waiting for workflow to start..."
        sleep 30
        iteration=$((iteration + 1))
        continue
    fi
    
    # Extract run details
    RUN_ID=$(echo $RUN_INFO | grep -o '"databaseId":[0-9]*' | head -1 | cut -d: -f2)
    STATUS=$(echo $RUN_INFO | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    CONCLUSION=$(echo $RUN_INFO | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo "Run ID: $RUN_ID"
    echo "Status: $STATUS"
    echo "Conclusion: $CONCLUSION"
    
    # If workflow is still running, wait
    if [ "$STATUS" != "completed" ]; then
        echo "Workflow is still running. Waiting ${SLEEP_TIME}s..."
        sleep $SLEEP_TIME
        continue
    fi
    
    # Check if workflow succeeded
    if [ "$CONCLUSION" = "success" ]; then
        echo "✅ WORKFLOW SUCCEEDED! All tests passed."
        echo "View results at: https://github.com/$REPO/actions/runs/$RUN_ID"
        exit 0
    fi
    
    # Workflow failed - need to analyze and fix
    echo "❌ WORKFLOW FAILED. Analyzing logs..."
    
    # Get failed jobs
    FAILED_JOBS=$(gh run view $RUN_ID --repo $REPO --json jobs 2>/dev/null | grep -o '"conclusion":"failure"' | wc -l)
    echo "Number of failed jobs: $FAILED_JOBS"
    
    # Try to identify the error
    echo "Fetching error logs..."
    
    # Get all job IDs that failed
    gh run view $RUN_ID --repo $REPO --json jobs 2>/dev/null | grep -o '"databaseId":[0-9]*' | cut -d: -f2 > /tmp/job_ids.txt
    
    ERROR_FOUND=false
    
    while read JOB_ID; do
        if [ -z "$JOB_ID" ]; then continue; fi
        
        echo "Checking job $JOB_ID..."
        
        # Get failed logs for this job
        LOGS=$(gh run view --log-failed --job=$JOB_ID --repo $REPO 2>&1)
        
        # Check for specific error patterns and create fix instructions
        if echo "$LOGS" | grep -q "Undeclared attribute type for enum"; then
            echo "🔍 Found: Enum validation error"
            echo "💡 Fix: Migration loading model with enum before column exists"
            echo "   Use SQL directly instead of ActiveRecord models in migrations"
            ERROR_FOUND=true
            
        elif echo "$LOGS" | grep -q "syntax error"; then
            echo "🔍 Found: Syntax error"
            echo "💡 Fix: Check Ruby syntax in the reported file"
            ERROR_FOUND=true
            
        elif echo "$LOGS" | grep -q "PG::UndefinedTable"; then
            echo "🔍 Found: Database table doesn't exist"
            echo "💡 Fix: Migration order issue - table needs to be created first"
            ERROR_FOUND=true
            
        elif echo "$LOGS" | grep -q "undefined method"; then
            echo "🔍 Found: Undefined method error"
            echo "💡 Fix: Check for typos or missing method definitions"
            ERROR_FOUND=true
            
        elif echo "$LOGS" | grep -q "cannot load such file"; then
            echo "🔍 Found: Missing file/require error"
            echo "💡 Fix: Check file paths and require statements"
            ERROR_FOUND=true
            
        elif echo "$LOGS" | grep -q "StandardError"; then
            echo "🔍 Found: StandardError in migration"
            echo "💡 Fix: Check migration logic and database state"
            ERROR_FOUND=true
        fi
        
        # Save logs for analysis
        echo "$LOGS" > /tmp/failed_job_$JOB_ID.log
        
    done < /tmp/job_ids.txt
    
    if [ "$ERROR_FOUND" = false ]; then
        echo "⚠️ Could not automatically identify the error pattern."
        echo "Logs saved to /tmp/failed_job_*.log"
        echo "Please manually review at: https://github.com/$REPO/actions/runs/$RUN_ID"
    fi
    
    echo ""
    echo "⏳ Waiting ${SLEEP_TIME}s before next check..."
    echo "(You can manually fix issues and push to trigger a new run)"
    sleep $SLEEP_TIME
    
    iteration=$((iteration + 1))
done

echo ""
echo "⚠️ Maximum iterations ($MAX_ITERATIONS) reached."
echo "Tests did not pass automatically. Manual intervention may be required."
echo "View latest run at: https://github.com/$REPO/actions"
exit 1