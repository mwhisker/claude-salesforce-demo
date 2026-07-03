#!/bin/bash
echo "🧪 Testing new pre-commit hook with simulated failures..."

# Track errors but continue running all checks
ERRORS=0
ERROR_MESSAGES=()

# Helper function to run commands and track errors
run_check() {
    local description=$1
    local command=$2
    
    echo "🔧 $description..."
    if eval "$command"; then
        echo "✅ $description passed"
    else
        echo "❌ $description failed"
        ERROR_MESSAGES+=("$description")
        ERRORS=$((ERRORS + 1))
    fi
}

# Test with a successful command
run_check "LWC unit tests" "npm run test:unit"

# Test with a failing command (simulate failure)
run_check "Simulated failing test" "false"

# Test with another successful command
run_check "Linting check" "npm run lint"

# Test with another failing command
run_check "Another simulated failure" "bash -c 'exit 1'"

# Summary of results
echo ""
echo "==================== PRE-COMMIT SUMMARY ===================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All pre-commit checks passed!"
    exit 0
else
    echo "❌ $ERRORS check(s) failed:"
    for error in "${ERROR_MESSAGES[@]}"; do
        echo "   • $error"
    done
    echo ""
    echo "💡 Fix the issues above and try again, or use 'git commit --no-verify' to skip"
    exit 1
fi
