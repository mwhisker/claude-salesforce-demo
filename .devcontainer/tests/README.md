# Devcontainer Testing Suite

This directory contains test scripts to validate the devcontainer setup and post-create script without running them automatically during devcontainer initialization.

## Test Scripts

### `run-all-tests.sh`

**Purpose**: Run all tests in sequence with a summary report
**Usage**: `./run-all-tests.sh`
**Safe**: ✅ Orchestrates all other test scripts

### `test-setup-dryrun.sh`

**Purpose**: Validate prerequisites and environment without making changes
**Usage**: `./test-setup-dryrun.sh`
**Safe**: ✅ Read-only, no system modifications

### `test-components.sh`

**Purpose**: Test individual components (npm scripts, SF CLI, Husky, etc.)
**Usage**: `./test-components.sh`
**Safe**: ✅ Runs actual commands but doesn't modify setup

### `test-precommit-hook.sh`

**Purpose**: Test the improved pre-commit hook logic with real scenarios
**Usage**: `./test-precommit-hook.sh`
**Safe**: ✅ Tests pre-commit using actual git operations

### `test-precommit-failures.sh`

**Purpose**: Test error handling behavior with simulated failures
**Usage**: `./test-precommit-failures.sh`
**Safe**: ✅ Simulates failures to validate error reporting

## How to Use

### Quick Start (Recommended)

```bash
# Run all tests at once
./.devcontainer/tests/run-all-tests.sh
```

### Individual Testing

1. **Before making changes to post-create.sh:**

    ```bash
    cd .devcontainer/tests
    chmod +x *.sh
    ./test-setup-dryrun.sh
    ```

2. **After making changes to validate they work:**

    ```bash
    ./test-components.sh
    ./test-precommit-hook.sh
    ```

3. **To test error handling:**
    ```bash
    ./test-precommit-failures.sh
    ```

## Integration with Devcontainer

These tests are **automatically excluded** from the devcontainer startup process because:

- They're in the `/tests/` subdirectory (not executed by post-create.sh)
- They require manual execution
- They're designed for development/debugging, not production setup

## Adding New Tests

When adding new test scripts:

1. Make them executable: `chmod +x script-name.sh`
2. Add descriptive echo statements
3. Use the `run_check()` pattern for consistent error handling
4. Document the purpose and safety level in this README

## Safety Levels

- ✅ **Safe**: Read-only or non-destructive operations
- ⚠️ **Caution**: May modify files but easily reversible
- ❌ **Dangerous**: Could break the environment (avoid in tests)
