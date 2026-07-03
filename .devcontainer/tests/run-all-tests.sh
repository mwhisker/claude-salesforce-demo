#!/bin/bash
# Helper script to run all tests in sequence

echo "🧪 Running full test suite for devcontainer setup..."
echo "=================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS=()

run_test() {
    local test_name=$1
    local test_script=$2
    
    echo ""
    echo "🔬 Running: $test_name"
    echo "----------------------------------------"
    
    if "$SCRIPT_DIR/$test_script"; then
        echo "✅ $test_name: PASSED"
        TEST_RESULTS+=("✅ $test_name")
    else
        echo "❌ $test_name: FAILED"
        TEST_RESULTS+=("❌ $test_name")
    fi
}

# Run tests in logical order
run_test "Environment Dry Run" "test-setup-dryrun.sh"
run_test "Component Tests" "test-components.sh"
run_test "Pre-commit Hook Tests" "test-precommit-hook.sh"

# Special handling for error handling test (expects failure)
echo ""
echo "🔬 Running: Error Handling Tests"
echo "----------------------------------------"
echo "ℹ️  Note: This test intentionally simulates failures to validate error handling"

if "$SCRIPT_DIR/test-precommit-failures.sh"; then
    echo "❌ Error Handling Tests: UNEXPECTED PASS (should have failed)"
    TEST_RESULTS+=("❌ Error Handling Tests (unexpected pass)")
else
    echo "✅ Error Handling Tests: EXPECTED FAILURE (error handling working)"
    TEST_RESULTS+=("✅ Error Handling Tests (expected failure)")
fi

# Summary
echo ""
echo "=================================================="
echo "🎯 TEST SUITE SUMMARY"
echo "=================================================="
for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

# Count results
passed=$(echo "${TEST_RESULTS[@]}" | grep -o "✅" | wc -l)
failed=$(echo "${TEST_RESULTS[@]}" | grep -o "❌" | wc -l)

echo ""
echo "📊 Results: $passed passed, $failed failed"

if [ $failed -eq 0 ]; then
    echo "🎉 All tests passed! Your devcontainer setup is ready."
    exit 0
else
    echo "⚠️  Some tests failed. Review the output above."
    exit 1
fi
