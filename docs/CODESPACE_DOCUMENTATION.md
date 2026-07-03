# Salesforce Devcontainer Codespace - Complete Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Environment Setup](#environment-setup)
- [VS Code Extensions](#vs-code-extensions)
- [Development Workflow](#development-workflow)
- [Testing Framework](#testing-framework)
- [Code Quality Gates](#code-quality-gates)
- [Git Configuration](#git-configuration)
- [Available Commands](#available-commands)
- [Troubleshooting](#troubleshooting)
- [Advanced Customization](#advanced-customization)

---

## Overview

This devcontainer template provides a complete, zero-configuration Salesforce development environment optimized for GitHub Codespaces and local VS Code devcontainers. It includes automated setup, comprehensive testing, code quality enforcement, and intelligent pre-commit hooks.

### Key Features

- **Automated Setup**: Complete environment configuration in one command
- **Comprehensive Testing**: 5 specialized test scripts covering all aspects
- **Smart Quality Gates**: Pre-commit hooks that adapt to your changes
- **Modern Tooling**: Latest Salesforce CLI, Node 20, Husky v9
- **Developer-Friendly**: Clear error messages and helpful guidance

### Technology Stack

- **Base Image**: Node.js 20 (Debian Bullseye)
- **Salesforce CLI**: v2 (latest @salesforce/cli)
- **Runtime**: Node.js 20.x
- **Package Manager**: npm
- **Git Hooks**: Husky v9
- **Testing**: Jest 29.7.0 with Salesforce LWC Jest

---

## Architecture

### Directory Structure

```
salesforce-devcontainer-template/
├── .devcontainer/
│   ├── devcontainer.json          # Main devcontainer configuration
│   ├── post-create.sh             # Automated setup script
│   └── tests/                     # Comprehensive test suite
│       ├── run-all-tests.sh       # Test orchestrator
│       ├── test-setup-dryrun.sh   # Environment validation
│       ├── test-components.sh     # Component testing
│       ├── test-precommit-hook.sh # Hook integration tests
│       └── test-precommit-failures.sh # Error handling tests
├── .vscode/
│   └── settings.json              # VS Code workspace settings
├── .husky/
│   └── pre-commit                 # Pre-commit quality gate
├── force-app/                     # Salesforce source code
├── jest.config.js                 # Jest test configuration
├── package.json                   # NPM dependencies and scripts
├── .eslintrc.json                 # ESLint configuration
├── .prettierrc                    # Prettier configuration
└── sfdx-project.json              # Salesforce project metadata
```

### Lifecycle Flow

1. **Codespace Creation**
   - Base container is created from Node.js 20 image
   - Features (Java, GitHub CLI, Git) are installed
   - `post-create.sh` runs automatically

2. **Post-Create Setup** (.devcontainer/post-create.sh)
   - Installs Salesforce CLI globally
   - Installs development tools (Prettier, ESLint, Claude Code)
   - Configures Salesforce CLI plugins
   - Sets up Git configuration from GitHub identity
   - Installs project dependencies
   - Configures Husky git hooks
   - Creates intelligent pre-commit hook

3. **Development Workflow**
   - Code changes trigger format-on-save
   - Pre-commit hook validates changes before commit
   - Tests run automatically based on file types changed

---

## Environment Setup

### Automated Installation

The `post-create.sh` script handles all setup automatically:

#### 1. Salesforce CLI Installation

```bash
npm install -g @salesforce/cli
```

Installs the latest Salesforce CLI v2 globally.

#### 2. Development Tools

```bash
npm install -g prettier prettier-plugin-apex @anthropic-ai/claude-code
```

- **prettier**: Code formatter
- **prettier-plugin-apex**: Apex language support for Prettier
- **claude-code**: AI-powered coding assistant

#### 3. Salesforce CLI Plugins

```bash
sf plugins install @salesforce/sfdx-scanner
sf plugins install @salesforce/lwc-dev-server
sf plugins install code-analyzer
```

- **sfdx-scanner**: Code analysis and security scanning
- **lwc-dev-server**: Local LWC development server
- **code-analyzer**: Advanced code analysis

Note: Scanner plugin requires Node.js >= 20 (automatically enforced).

#### 4. Git Configuration

Automatically configures Git using your GitHub identity:

```bash
gh api user  # Fetches GitHub profile
git config --global user.name "<Your GitHub Name>"
git config --global user.email "<userid>+<username>@users.noreply.github.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

Uses GitHub noreply email to ensure proper profile picture attribution.

#### 5. Project Dependencies

```bash
npm install
npx husky init
```

Installs all package.json dependencies and initializes Husky v9 git hooks.

### Port Forwarding

The following ports are automatically forwarded:

- **1717**: LWC Dev Server
- **3333**: Custom development servers
- **8080**: HTTP servers and proxies

### Container Features

Pre-installed features from devcontainer.json:

- **GitHub CLI** (ghcr.io/devcontainers/features/github-cli:1)
- **Java 11** (ghcr.io/devcontainers/features/java:1)
- **Git** (ghcr.io/devcontainers/features/git:1)
- **Salesforce CLI Autocomplete** (ghcr.io/salesforce/features/salesforce-cli-autocomplete:1)

---

## VS Code Extensions

### Installed Extensions

The devcontainer automatically installs the following VS Code extensions:

#### Salesforce Extension Pack

1. **salesforce.salesforcedx-vscode** - Base Salesforce extension pack
2. **salesforce.salesforcedx-vscode-apex** - Apex language features
   - Syntax highlighting
   - IntelliSense
   - Code navigation
3. **salesforce.salesforcedx-vscode-core** - Core Salesforce functionality
   - Command palette integration
   - Org management
4. **salesforce.salesforcedx-vscode-apex-debugger** - Apex debugging
   - Breakpoints
   - Variable inspection
   - Step-through debugging
5. **salesforce.salesforcedx-vscode-apex-replay-debugger** - Replay debugging
   - Debug logs analysis
   - Historical debugging
6. **salesforce.salesforcedx-vscode-lightning** - Lightning development
   - Aura components support
7. **salesforce.salesforcedx-vscode-lwc** - Lightning Web Components
   - LWC syntax highlighting
   - Component IntelliSense
   - Template validation
8. **salesforce.salesforcedx-vscode-visualforce** - Visualforce support
   - VF page and component support

#### Code Quality Extensions

9. **redhat.vscode-xml** - XML language support
   - XML validation
   - Schema support
10. **dbaeumer.vscode-eslint** - JavaScript linting
    - Real-time error detection
    - Auto-fix on save
11. **esbenp.prettier-vscode** - Code formatting
    - Format on save
    - Multi-language support
12. **ms-vscode.vscode-json** - Enhanced JSON support
    - Schema validation
    - IntelliSense

### VS Code Settings

Configured in `.vscode/settings.json`:

```json
{
  // Salesforce
  "salesforcedx-vscode-core.push-or-deploy-on-save.enabled": true,
  "salesforcedx-vscode-core.push-or-deploy-on-save.preferDeployOnSave": true,

  // Editor
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },

  // Prettier
  "prettier.tabWidth": 4,

  // Search exclusions
  "search.exclude": {
    "**/node_modules": true,
    "**/.sfdx": true,
    "**/.localdevserver": true
  }
}
```

Key behaviors:
- **Auto-deploy on save**: Changes automatically deploy to connected org
- **Format on save**: All files auto-formatted with Prettier
- **ESLint auto-fix**: JavaScript errors auto-fixed on save
- **Smart search**: Excludes build directories from search

---

## Development Workflow

### 1. Initial Setup

When you first open the codespace:

```bash
# Authenticate with Salesforce (if needed)
sf org login web --set-default-dev-hub --alias DevHub

# Or authenticate with org
sf org login web --set-default --alias MyScratchOrg

# List connected orgs
npm run org:list
```

### 2. Daily Development

```bash
# Pull latest from org
npm run retrieve

# Make code changes (auto-format on save)

# Run tests locally
npm test

# Deploy to org
npm run deploy

# Open org
npm run org:open
```

### 3. Code Quality Workflow

```bash
# Check linting
npm run lint

# Auto-fix linting issues
npm run lint:fix

# Format all files
npm run prettier

# Verify formatting
npm run prettier:verify

# Run full validation (lint + prettier + tests)
npm run validate
```

### 4. Commit Workflow

```bash
# Stage changes
git add .

# Commit (triggers pre-commit hook)
git commit -m "feat: add new feature"

# Pre-commit hook automatically:
# 1. Runs LWC unit tests
# 2. Runs Apex tests (if .cls/.trigger files changed AND org connected)
# 3. Formats and lints staged files
# 4. Reports all errors together
```

### 5. Testing Workflow

```bash
# Run LWC unit tests
npm run test:unit

# Run with coverage
npm run test:unit:coverage

# Run in watch mode
npm run test:unit:watch

# Run Apex tests (requires connected org)
npm run test:apex

# Run all tests
npm run test:all
```

---

## Testing Framework

### Test Suite Overview

Five specialized test scripts in `.devcontainer/tests/`:

#### 1. run-all-tests.sh (Test Orchestrator)

**Purpose**: Runs all tests in sequence and provides summary report

**Usage**:
```bash
.devcontainer/tests/run-all-tests.sh
```

**What it does**:
- Runs all 4 test scripts sequentially
- Tracks pass/fail status
- Provides comprehensive summary
- Handles expected failures gracefully

**Output Example**:
```
=== Test Summary ===
✓ Setup dry-run test: PASSED
✓ Component tests: PASSED
✓ Pre-commit hook test: PASSED
✓ Pre-commit failure handling: PASSED (some failures are expected)

Overall: PASSED
```

#### 2. test-setup-dryrun.sh (Environment Validation)

**Purpose**: Validates environment setup without making changes

**Safety Level**: 🟢 100% Read-only

**Usage**:
```bash
.devcontainer/tests/test-setup-dryrun.sh
```

**What it validates**:
- Node.js version (>= 20)
- Required tools (npm, git, sf, gh, prettier, eslint)
- Package.json scripts existence
- Package.json dependencies
- Git configuration (user.name, user.email)
- GitHub CLI authentication status

**Key Feature**: Never modifies anything - perfect for validation.

#### 3. test-components.sh (Component Testing)

**Purpose**: Tests individual components of the setup

**Safety Level**: 🟡 Mostly safe (creates test files, auto-cleans)

**Usage**:
```bash
.devcontainer/tests/test-components.sh
```

**What it tests**:
- LWC Jest tests execution
- ESLint linting
- Prettier formatting
- Lint-staged configuration
- Salesforce CLI and plugins
- Husky setup
- Pre-commit hook executability

**Auto-cleanup**: Removes any test files created.

#### 4. test-precommit-hook.sh (Hook Integration)

**Purpose**: Tests pre-commit hook in real Git environment

**Safety Level**: 🟡 Creates test commits, auto-reverts

**Usage**:
```bash
.devcontainer/tests/test-precommit-hook.sh
```

**What it tests**:
- Pre-commit hook execution
- Hook error handling
- Git integration
- Staged file processing

**Auto-cleanup**: Reverts test commits and removes test files.

#### 5. test-precommit-failures.sh (Error Handling)

**Purpose**: Validates error collection and reporting

**Safety Level**: 🟡 Creates test files, auto-cleans

**Usage**:
```bash
.devcontainer/tests/test-precommit-failures.sh
```

**What it tests**:
- Error detection and collection
- Continue-on-error behavior
- Error message formatting
- Multiple error reporting

**Expected Result**: Some failures are expected (to test error handling).

### Running Tests

```bash
# Run all tests
.devcontainer/tests/run-all-tests.sh

# Run individual tests
.devcontainer/tests/test-setup-dryrun.sh
.devcontainer/tests/test-components.sh
.devcontainer/tests/test-precommit-hook.sh
.devcontainer/tests/test-precommit-failures.sh

# Run via npm
npm test                    # LWC unit tests only
npm run test:unit          # Same as npm test
npm run test:apex          # Apex tests (requires org)
npm run test:all           # Both unit and Apex tests
```

---

## Code Quality Gates

### Pre-Commit Hook

Location: `.husky/pre-commit`

**Intelligent Quality Gate** that adapts to your changes:

#### Workflow

1. **Always Runs**: LWC unit tests (fast, local, no org needed)
2. **Conditionally Runs**: Apex tests only if:
   - `.cls` or `.trigger` files are staged, AND
   - A Salesforce org is connected
3. **Always Runs**: lint-staged (formatting and linting)
4. **Error Collection**: Continues running all checks, reports all errors together

#### Smart Apex Test Detection

```bash
# Checks for Apex files in commit
if git diff --cached --name-only | grep -qE '\.(cls|trigger)$'; then
  # Only runs if org is connected
  if sf org list --json | grep -q '"username"'; then
    echo "Running Apex tests..."
    npm run test:apex
  fi
fi
```

**Benefits**:
- No wasted time on Apex tests for UI-only changes
- No failures when org isn't connected
- Automatic detection - no manual intervention needed

#### Error Reporting

```bash
=== PRE-COMMIT SUMMARY ===
✗ LWC unit tests: FAILED
✓ lint-staged: PASSED

Fix the errors above and try again, or use 'git commit --no-verify' to skip checks.
```

All errors are shown together, allowing you to fix all issues at once.

#### Bypassing the Hook

```bash
# Skip pre-commit checks (use sparingly)
git commit --no-verify -m "emergency fix"
```

### Lint-Staged Configuration

Location: `package.json` (lines 43-57)

**File-Type Specific Processing**:

```json
{
  "*.{cls,trigger}": ["prettier --write"],
  "force-app/**/*.js": ["eslint --fix", "prettier --write"],
  "*.{html,css}": ["prettier --write"],
  "*.{json,md,yaml,yml}": ["prettier --write"]
}
```

**How it works**:
- Only processes files in staging area
- Automatically re-stages formatted files
- Runs different tools based on file extension
- Apex files: Prettier with apex plugin
- JavaScript files: ESLint auto-fix, then Prettier
- Markup files: Prettier only

### ESLint Configuration

Location: `.eslintrc.json`

**Setup**:
```json
{
  "extends": "@salesforce/eslint-config-lwc/recommended",
  "env": { "es2022": true },
  "overrides": [
    {
      "files": ["**/__tests__/**"],
      "env": { "jest": true },
      "rules": {
        "@lwc/lwc/no-unexpected-wire-adapter-usages": "off"
      }
    }
  ]
}
```

**Features**:
- Salesforce LWC recommended rules
- ES2022 syntax support
- Relaxed rules for test files
- Jest environment for tests

### Prettier Configuration

Location: `.prettierrc`

**Settings**:
```json
{
  "tabWidth": 4,
  "printWidth": 80,
  "trailingComma": "none",
  "overrides": [
    {
      "files": "*.html",
      "options": { "parser": "lwc" }
    },
    {
      "files": "*.{page,component}",
      "options": { "parser": "visualforce" }
    }
  ]
}
```

**Features**:
- 4-space indentation (Salesforce standard)
- 80-character line width
- No trailing commas
- LWC HTML parser for templates
- Visualforce parser for VF pages

---

## Git Configuration

### Automatic Setup

The `post-create.sh` script automatically configures Git using your GitHub identity:

```bash
# Fetches your GitHub profile
gh api user

# Configures Git
git config --global user.name "Your Name"
git config --global user.email "12345+username@users.noreply.github.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

### GitHub Noreply Email

Uses format: `<userid>+<username>@users.noreply.github.com`

**Benefits**:
- GitHub recognizes commits as yours
- Profile picture appears in commit history
- Email privacy maintained
- Commit authorship properly attributed

### Default Configurations

- **Default branch**: `main`
- **Pull strategy**: Merge (no rebase)
- **User info**: From GitHub CLI
- **Commit signing**: Not configured by default

### Manual Override

If you need to use different settings:

```bash
# Use custom email
git config --global user.email "your@email.com"

# Use custom name
git config --global user.name "Your Custom Name"

# Enable commit signing
git config --global commit.gpgsign true
```

---

## Available Commands

### NPM Scripts

Defined in `package.json`:

#### Testing Commands

```bash
npm test                    # Run LWC unit tests
npm run test:unit          # Run LWC unit tests (Jest)
npm run test:unit:watch    # Run tests in watch mode
npm run test:unit:coverage # Run tests with coverage report
npm run test:apex          # Run Apex tests (requires connected org)
npm run test:all           # Run both unit and Apex tests
```

#### Code Quality Commands

```bash
npm run lint               # Check for linting errors
npm run lint:fix           # Auto-fix linting errors
npm run prettier           # Format all files
npm run prettier:verify    # Check if files are formatted
npm run validate           # Run lint + prettier + tests
```

#### Salesforce Commands

```bash
npm run deploy             # Deploy source to org
npm run deploy:check       # Validate deployment (dry-run)
npm run retrieve           # Retrieve source from org
npm run org:open           # Open default org in browser
npm run org:list           # List all connected orgs
```

### Salesforce CLI Commands

Common SF CLI commands available:

```bash
# Org authentication
sf org login web --set-default --alias MyOrg
sf org login web --set-default-dev-hub --alias DevHub
sf org logout --target-org MyOrg

# Org management
sf org list
sf org display
sf org open

# Source operations
sf project deploy start
sf project deploy start --dry-run
sf project retrieve start
sf project deploy start --source-dir force-app

# Apex operations
sf apex run --file scripts/apex/hello.apex
sf apex run test --test-level RunLocalTests
sf apex get log --log-id <id>

# Data operations
sf data query --query "SELECT Id, Name FROM Account LIMIT 10"
sf data import tree --plan data/plan.json
sf data export tree --query "SELECT..."

# LWC development
sf lightning lwc start
sf lightning lwc test
```

### Git Commands

```bash
# Standard workflow
git status
git add .
git commit -m "message"
git push

# Branch operations
git checkout -b feature/new-feature
git checkout main
git merge feature/new-feature

# Viewing history
git log --oneline
git log --graph --oneline --all

# Bypassing pre-commit (use sparingly)
git commit --no-verify -m "emergency fix"
```

---

## Troubleshooting

### Common Issues

#### 1. Pre-commit Hook Fails

**Symptom**: Commit is rejected with test failures

**Solution**:
```bash
# Run tests manually to see detailed errors
npm test

# Fix errors, then retry commit
git add .
git commit -m "your message"

# Or skip if necessary (use sparingly)
git commit --no-verify -m "your message"
```

#### 2. Salesforce CLI Not Found

**Symptom**: `sf: command not found`

**Solution**:
```bash
# Reinstall Salesforce CLI
npm install -g @salesforce/cli

# Verify installation
sf --version
```

#### 3. Git User Not Configured

**Symptom**: Git commit asks for user name/email

**Solution**:
```bash
# Authenticate with GitHub CLI
gh auth login

# Re-run git configuration
git config --global user.name "$(gh api user -q .name)"
git config --global user.email "$(gh api user -q .id)+$(gh api user -q .login)@users.noreply.github.com"
```

#### 4. Husky Hooks Not Working

**Symptom**: Pre-commit hook doesn't run

**Solution**:
```bash
# Reinitialize Husky
npx husky init

# Verify hook exists and is executable
ls -la .husky/pre-commit
chmod +x .husky/pre-commit
```

#### 5. Port Already in Use

**Symptom**: LWC dev server won't start on port 1717

**Solution**:
```bash
# Find process using port
lsof -i :1717

# Kill process
kill -9 <PID>

# Or use different port
sf lightning lwc start --port 1234
```

#### 6. Apex Tests Timeout

**Symptom**: `npm run test:apex` times out

**Solution**:
```bash
# Check org connection
sf org display

# Re-authenticate if needed
sf org login web

# Run tests directly with SF CLI
sf apex run test --test-level RunLocalTests --wait 10
```

#### 7. ESLint Errors After Update

**Symptom**: New ESLint errors after dependency update

**Solution**:
```bash
# Clear ESLint cache
rm -rf node_modules/.cache

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Run lint fix
npm run lint:fix
```

### Debugging Tips

#### Enable Verbose Logging

```bash
# Salesforce CLI debug mode
export SF_LOG_LEVEL=debug
sf project deploy start

# NPM debug mode
npm run test --verbose

# Git hook debugging
export HUSKY_DEBUG=1
git commit -m "test"
```

#### Check Test Output

```bash
# Run setup validation
.devcontainer/tests/test-setup-dryrun.sh

# Run all tests
.devcontainer/tests/run-all-tests.sh

# Check specific component
.devcontainer/tests/test-components.sh
```

#### Verify Environment

```bash
# Check Node version (should be 20.x)
node --version

# Check Salesforce CLI
sf --version
sf plugins

# Check GitHub CLI
gh --version
gh auth status

# Check Git config
git config --global --list
```

---

## Advanced Customization

### Adding Custom Extensions

Edit `.devcontainer/devcontainer.json`:

```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        // Add your extension ID here
        "ms-azuretools.vscode-docker"
      ]
    }
  }
}
```

### Modifying Pre-Commit Hook

Edit `.husky/pre-commit`:

```bash
#!/bin/sh

# Add custom checks
echo "Running custom validation..."
./scripts/custom-check.sh

# Call original hook logic
npm test
npx lint-staged
```

### Adding Custom NPM Scripts

Edit `package.json`:

```json
{
  "scripts": {
    "custom:deploy": "sf project deploy start --source-dir force-app/custom",
    "custom:validate": "./scripts/custom-validation.sh"
  }
}
```

### Configuring Additional Ports

Edit `.devcontainer/devcontainer.json`:

```json
{
  "forwardPorts": [1717, 3333, 8080, 5000, 9000]
}
```

### Adding Salesforce CLI Plugins

Edit `.devcontainer/post-create.sh`:

```bash
# Add after existing plugin installations
sf plugins install @salesforce/plugin-data
sf plugins install @salesforce/plugin-community
```

### Customizing Code Quality Rules

**ESLint** (`.eslintrc.json`):
```json
{
  "rules": {
    "no-console": "warn",
    "prefer-const": "error"
  }
}
```

**Prettier** (`.prettierrc`):
```json
{
  "tabWidth": 2,
  "semi": true,
  "singleQuote": true
}
```

**Lint-staged** (`package.json`):
```json
{
  "lint-staged": {
    "*.{cls,trigger}": ["prettier --write", "custom-apex-linter"],
    "*.js": ["eslint --fix", "custom-js-check", "prettier --write"]
  }
}
```

### Environment Variables

Add to `.devcontainer/devcontainer.json`:

```json
{
  "containerEnv": {
    "SF_DOMAIN_RETRY": "300",
    "SF_LOG_LEVEL": "info",
    "NODE_ENV": "development"
  }
}
```

### Post-Create Commands

Add to `.devcontainer/devcontainer.json`:

```json
{
  "postCreateCommand": "bash .devcontainer/post-create.sh && ./scripts/custom-setup.sh"
}
```

---

## Best Practices

### 1. Commit Frequency

- Commit often with meaningful messages
- Use conventional commit format: `feat:`, `fix:`, `docs:`, `refactor:`
- Let pre-commit hook catch issues early

### 2. Testing Strategy

- Write unit tests for all LWC components
- Run tests locally before pushing
- Use `npm run validate` before submitting PRs
- Add Apex tests for business logic

### 3. Code Quality

- Rely on auto-format on save
- Fix linting errors as they appear
- Review pre-commit feedback carefully
- Don't use `--no-verify` unless absolutely necessary

### 4. Org Management

- Use meaningful org aliases
- Keep scratch orgs for feature development
- Use sandboxes for integration testing
- Deploy to production via CI/CD only

### 5. Extension Management

- Only install necessary extensions
- Review extension permissions
- Keep extensions updated
- Document custom extensions in project README

---

## Support and Resources

### Documentation

- [Salesforce CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Lightning Web Components Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Devcontainers Documentation](https://containers.dev/)
- [Husky Documentation](https://typicode.github.io/husky/)

### Useful Links

- [Salesforce Extensions for VS Code](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
- [Prettier Apex Plugin](https://github.com/dangmai/prettier-plugin-apex)
- [ESLint LWC Plugin](https://github.com/salesforce/eslint-plugin-lwc)

### Getting Help

- Check the troubleshooting section above
- Run `.devcontainer/tests/test-setup-dryrun.sh` to validate environment
- Review test output for specific errors
- Consult Salesforce Stack Exchange for Salesforce-specific issues
- Check GitHub Issues for devcontainer-related problems

---

## Appendix

### File Reference

| File | Purpose | Modify? |
|------|---------|---------|
| `.devcontainer/devcontainer.json` | Main devcontainer config | Customize extensions, ports |
| `.devcontainer/post-create.sh` | Automated setup script | Add custom setup steps |
| `.vscode/settings.json` | VS Code workspace settings | Customize editor behavior |
| `.husky/pre-commit` | Pre-commit quality gate | Add custom checks |
| `package.json` | NPM dependencies and scripts | Add scripts, dependencies |
| `.eslintrc.json` | ESLint rules | Customize linting rules |
| `.prettierrc` | Prettier formatting | Customize formatting |
| `jest.config.js` | Jest test configuration | Customize test behavior |
| `sfdx-project.json` | Salesforce project metadata | Update API version, packages |

### Version Information

- **Devcontainer Version**: 1.0
- **Node.js**: 20.x
- **Salesforce CLI**: v2 (latest)
- **Jest**: 29.7.0
- **Husky**: 9.0.0
- **ESLint**: 8.57.0
- **Prettier**: 3.5.3
- **Salesforce API**: 63.0

---

*Last Updated: 2025-11-17*
