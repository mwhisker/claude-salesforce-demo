#!/bin/bash
echo "🧪 Testing pre-commit hook execution..."

# Check if hook exists and is executable
if [ ! -f ".husky/pre-commit" ] || [ ! -x ".husky/pre-commit" ]; then
    echo "❌ Pre-commit hook not found or not executable"
    exit 1
fi

echo "✅ Pre-commit hook exists and is executable"
echo "📄 Current hook content:"
echo "----------------------------------------"
cat .husky/pre-commit
echo "----------------------------------------"

# Save current Git state
ORIGINAL_STAGED=$(git diff --cached --name-only)

# Create a temporary test file to stage
echo "// Test file for pre-commit hook testing - $(date)" > temp-precommit-test.js
git add temp-precommit-test.js

echo ""
echo "🔧 Testing pre-commit hook execution with staged file..."
echo "Staged files:"
git diff --cached --name-only

# Execute pre-commit hook
echo ""
echo "Running pre-commit hook..."
if ./.husky/pre-commit; then
    echo "✅ Pre-commit hook executed successfully"
    HOOK_RESULT="passed"
else
    echo "❌ Pre-commit hook failed"
    HOOK_RESULT="failed"
fi

# Clean up: restore original Git state
echo ""
echo "🧹 Cleaning up test environment..."
git reset HEAD temp-precommit-test.js 2>/dev/null || true
rm -f temp-precommit-test.js

# Restore any originally staged files
if [ -n "$ORIGINAL_STAGED" ]; then
    echo "$ORIGINAL_STAGED" | xargs git add 2>/dev/null || true
    echo "✅ Restored originally staged files"
fi

echo ""
echo "==================== PRE-COMMIT HOOK TEST SUMMARY ===================="
echo "Hook execution result: $HOOK_RESULT"
echo "✅ Pre-commit hook behavior validated!"

# Exit with appropriate code
if [ "$HOOK_RESULT" = "passed" ]; then
    exit 0
else
    echo "💡 Hook failure might be expected if environment isn't fully set up"
    exit 1
fi
