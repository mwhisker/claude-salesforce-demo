# Salesforce Development Template

A complete, production-ready development environment template for Salesforce projects with GitHub Codespaces. Features automated setup, comprehensive testing, and robust code quality enforcement.

## 🚀 Quick Start

1. **Use this template** to create a new repository
2. **Open in Codespace** - Click "Code" → "Codespaces" → "Create codespace"
3. **Wait for setup** - The devcontainer will install all dependencies (3-5 minutes)
4. **Authenticate**: `sf org login web --alias myorg`
5. **Set default org**: `sf config set target-org myorg`
6. **Start developing** - All tools and quality checks are ready!

## ✨ What's Included

### 🔧 Development Environment

- **DevContainer configuration** - Node.js 20, Java 11, automated setup
- **Salesforce CLI v2.97+** with essential plugins pre-installed:
    - `sfdx-scanner` - Static code analysis
    - `code-analyzer` - Advanced code quality checks
    - `lwc-dev-server` - Local Lightning Web Component development
- **VS Code extensions** - Complete Salesforce development pack
- **GitHub CLI** - Integrated GitHub operations

### 🧪 Testing & Quality Assurance

- **Jest for LWC** - Lightning Web Component unit testing
- **ESLint & Prettier** - Code formatting and linting
- **Pre-commit hooks** - Automated quality checks before commits
- **Comprehensive test suite** - Validate your devcontainer setup
- **Husky v9** - Modern git hooks with error collection

### 📋 Code Quality Features

- **Smart pre-commit checks** that continue on errors to show all issues
- **Apex test automation** - Runs only when Apex files are modified
- **LWC unit tests** - Always runs (fast, local validation)
- **Lint-staged integration** - Only checks modified files
- **Informative error reporting** - Clear feedback on what needs fixing

## 🛠️ Available Commands

### Development

```bash
# Deploy to org
npm run deploy
npm run deploy:check    # Validate without deploying

# Retrieve from org
npm run retrieve

# Open org
npm run org:open
```

### Testing

```bash
# Run all tests
npm run test

# Unit tests only (LWC)
npm run test:unit
npm run test:unit:watch     # Watch mode
npm run test:unit:coverage  # With coverage

# Apex tests (requires org connection)
npm run test:apex
```

### Code Quality

```bash
# Format code
npm run prettier
npm run prettier:verify

# Lint code
npm run lint
npm run lint:fix
```

### Validation & Testing

```bash
# Test your devcontainer setup
.devcontainer/tests/run-all-tests.sh

# Test individual components
.devcontainer/tests/test-setup-dryrun.sh    # Prerequisites check
.devcontainer/tests/test-components.sh      # LWC and tools
.devcontainer/tests/test-precommit-hook.sh  # Hook execution
```

## 🧪 Built-in Testing Suite

This template includes a comprehensive testing framework to validate your development environment:

- **Setup validation** - Checks Node.js, tools, dependencies
- **Component testing** - Validates LWC compilation and Jest execution
- **Pre-commit simulation** - Tests hooks with both success and failure scenarios
- **Git integration** - Ensures all git operations work correctly

Run `.devcontainer/tests/run-all-tests.sh` to validate your environment after setup.

## 🎯 Pre-commit Quality Gates

Automatic quality checks run before each commit:

- ✅ **LWC unit tests** - Fast, always runs
- ✅ **Apex tests** - Smart detection (only when `.cls`/`.trigger` files change)
- ✅ **Code formatting** - ESLint + Prettier via lint-staged
- ✅ **Error collection** - See all issues at once, not just the first failure
- ✅ **Informative messaging** - Clear feedback on what's being checked

Skip with `git commit --no-verify` if needed.

## 🚀 Getting Started with Development

1. **Create your first component**:

    ```bash
    sf lightning generate component myComponent --type lwc
    ```

2. **Write tests** in `force-app/main/default/lwc/myComponent/__tests__/`

3. **Commit your changes** - Quality checks run automatically

4. **Deploy when ready**:
    ```bash
    npm run deploy:check  # Validate first
    npm run deploy        # Deploy to org
    ```

## 🔧 Customization

This template is designed to be easily customizable:

- **Modify `.devcontainer/devcontainer.json`** for different Node.js versions or additional tools
- **Update `.husky/pre-commit`** to adjust quality gate requirements
- **Customize `package.json` scripts** for your specific workflow
- **Add VS Code settings** in `.vscode/settings.json` for team preferences

## 📖 Learn More

- [Salesforce CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Lightning Web Components](https://lwc.dev/)
- [VS Code Salesforce Extensions](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)

---
