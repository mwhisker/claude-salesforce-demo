# Salesforce Development Environment - Automated Testing & Code Quality

This document outlines the automated testing, linting, and formatting pipeline configured in this Salesforce development environment.

## 📋 Overview

This environment provides automated code quality checks at multiple stages:

- **On Save**: Automatic formatting and linting in VS Code
- **On Commit**: Comprehensive testing, linting, and formatting via Husky pre-commit hooks
- **Manual Validation**: Full pipeline validation via npm scripts

## 🔧 Tools & Technologies

| Tool               | Version        | Purpose                 |
| ------------------ | -------------- | ----------------------- |
| **Husky**          | v9.1.7         | Git hooks management    |
| **lint-staged**    | v15.0.0        | Staged files processing |
| **ESLint**         | v8.57.0        | JavaScript linting      |
| **Prettier**       | v3.5.3         | Code formatting         |
| **Jest/LWC Jest**  | v29.7.0/v3.1.0 | Unit testing            |
| **Salesforce CLI** | Latest         | Apex testing            |

## 💾 On Save Automation

### VS Code Settings (`.vscode/settings.json`)

```json
{
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.fixAll.eslint": "explicit"
    },
    "prettier.defaultFormatter": "esbenp.prettier-vscode"
}
```

### What Happens on Save:

1. **ESLint Auto-Fix** - Automatically fixes JavaScript issues
2. **Prettier Formatting** - Formats all supported file types
3. **Immediate Feedback** - Shows errors/warnings in VS Code

## 🔄 On Commit Automation (Pre-Commit Hook)

### Execution Order:

#### 1. **LWC Unit Tests** (Always Runs)

```bash
npm run test:unit
# Runs: sfdx-lwc-jest --skipApiVersionCheck -- --passWithNoTests
```

- **Purpose**: Validate Lightning Web Component functionality
- **Speed**: Fast (local execution)
- **API Version**: Bypasses version check for API v63.0
- **Behavior**: Passes when no tests exist

#### 2. **Conditional Apex Tests** (Smart Detection)

```bash
if git diff --cached --name-only | grep -q "\.cls$\|\.trigger$"; then
    if sf org display --json > /dev/null 2>&1; then
        npm run test:apex
    else
        echo "⚠️ Apex files changed but no org connected"
    fi
fi
```

- **Trigger**: Only when `.cls` or `.trigger` files are modified
- **Requirement**: Connected Salesforce org
- **Fallback**: Warning message if no org connected
- **Command**: `sf apex run test --wait 10 --result-format human --code-coverage`

#### 3. **Lint-Staged Processing** (File-Type Specific)

```bash
npx lint-staged
```

##### Apex Files (`*.cls`, `*.trigger`):

```bash
prettier --write --plugin prettier-plugin-apex
```

##### LWC JavaScript (`force-app/**/lwc/**/*.js`):

```bash
eslint --fix
prettier --write
```

##### LWC Templates/Styles (`force-app/**/lwc/**/*.{html,css}`):

```bash
prettier --write
```

##### Configuration Files (`*.{json,md,yaml,yml}`):

```bash
prettier --write
```

## 🛡️ Quality Gates

### Commit Prevention

Commits are **blocked** if any of these fail:

- ❌ LWC unit tests fail
- ❌ Apex tests fail (when org connected and Apex files changed)
- ❌ ESLint errors (not auto-fixable)
- ❌ Prettier formatting errors

### Success Indicators

- ✅ All tests pass
- ✅ Code automatically formatted
- ✅ Linting issues auto-fixed
- ✅ Clean commit history

## 📚 Manual Commands

### Individual Operations

```bash
# Linting
npm run lint              # Check LWC JavaScript
npm run lint:fix          # Fix LWC JavaScript issues

# Testing
npm run test              # Run LWC unit tests
npm run test:unit         # Same as above
npm run test:apex         # Run Apex tests (requires org)
npm run test:all          # Run both LWC and Apex tests

# Formatting
npm run prettier          # Format all files
npm run prettier:verify   # Check formatting without changes

# Complete Validation
npm run validate          # Run lint + prettier:verify + test:unit
```

### File Patterns

| Pattern                            | Files Included                  |
| ---------------------------------- | ------------------------------- |
| `force-app/**/lwc/**/*.js`         | LWC JavaScript components       |
| `force-app/**/*.{cls,trigger}`     | Apex classes and triggers       |
| `force-app/**/lwc/**/*.{html,css}` | LWC templates and styles        |
| `**/*.{json,md,yaml,yml}`          | Configuration and documentation |

## 🚀 Developer Experience Features

### Smart Detection

- **Apex Changes**: Only runs Apex tests when Apex files are modified
- **Org Connectivity**: Checks for connected Salesforce org before Apex tests
- **File Type Awareness**: Different processing for different file types

### Performance Optimizations

- **Staged Files Only**: lint-staged only processes files being committed
- **Conditional Execution**: Apex tests only when necessary
- **Fast LWC Tests**: Local Jest execution without org dependency

### Error Handling

- **Clear Messages**: Descriptive output with emojis for easy identification
- **Helpful Warnings**: Guidance when org not connected
- **Non-Blocking Warnings**: Development continues with appropriate messages

## 🔧 Configuration Files

### Core Configuration

- **`.husky/pre-commit`** - Pre-commit hook script
- **`package.json`** - NPM scripts and lint-staged configuration
- **`.eslintrc.json`** - ESLint rules for project
- **`jest.config.js`** - Jest configuration with LWC preset

### Environment Setup

- **`.devcontainer/devcontainer.json`** - VS Code dev container config
- **`.devcontainer/post-create.sh`** - Environment initialization script
- **`.vscode/settings.json`** - VS Code workspace settings

## 🎯 Benefits for Development Teams

### Code Quality

- **Consistent Formatting**: Automatic code formatting across team
- **Early Bug Detection**: Catches issues before code review
- **Standard Compliance**: Enforces Salesforce coding standards

### Developer Productivity

- **Automated Workflows**: Reduces manual QA steps
- **Fast Feedback**: Immediate error detection and correction
- **Template Ready**: Consistent setup across all team environments

### Team Collaboration

- **Clean Commits**: Prevents poorly formatted or broken code commits
- **Reduced Review Time**: Pre-validated code in pull requests
- **Standardized Environment**: Same tools and rules for all developers

## 🚨 Troubleshooting

### Common Issues

1. **"No org connected"** - Run `sf org login web` to authenticate
2. **ESLint errors** - Check `.eslintrc.json` configuration
3. **Prettier conflicts** - Verify file patterns in `package.json`
4. **Husky not running** - Ensure hooks are executable: `chmod +x .husky/pre-commit`

### Emergency Bypass

```bash
# Skip pre-commit hooks (use sparingly)
git commit --no-verify -m "emergency commit"

# Skip Husky entirely for one command
HUSKY=0 git commit -m "bypass husky"
```

---

_This documentation reflects the configuration as of the template creation. Update as the pipeline evolves._
