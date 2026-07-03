#!/bin/bash

echo "🚀 Setting up Salesforce development environment..."

# Install Salesforce CLI
echo "📦 Installing Salesforce CLI..."
npm install -g @salesforce/cli

# Install development dependencies (node, npm, eslint are pre-installed)
echo "📦 Installing development tools..."
npm install -g prettier prettier-plugin-apex
npm install -g @anthropic-ai/claude-code

# Install SFDX plugins that are commonly used
echo "🔌 Installing Salesforce CLI plugins..."
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)

# Check if SF CLI is available
if ! command -v sf &> /dev/null; then
    echo "❌ Salesforce CLI not found. Please install it first."
    exit 1
fi

# Install plugins with better error handling
install_plugin() {
    local plugin_name=$1
    local description=$2
    echo "Installing $description..."
    if sf plugins install "$plugin_name"; then
        echo "✅ Successfully installed $plugin_name"
    else
        echo "⚠️  Failed to install $plugin_name - continuing anyway"
    fi
}

if [ "$NODE_VERSION" -ge 20 ]; then
    install_plugin "@salesforce/sfdx-scanner" "SFDX Scanner"
else
    echo "⚠️  Skipping @salesforce/sfdx-scanner (requires Node.js >=20, current: $(node --version))"
fi

install_plugin "@salesforce/lwc-dev-server" "LWC Dev Server"
install_plugin "code-analyzer" "Code Analyzer"

echo "✅ Salesforce CLI plugin installation complete"

# Set up git configuration for better development experience
echo "⚙️ Configuring Git..."
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input

# Configure Git user from GitHub CLI if available
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    echo "🔧 Configuring Git user from GitHub..."
    
    # Get GitHub user info safely using multiple API calls
    GITHUB_NAME=$(gh api user --jq '.name // .login' 2>/dev/null)
    GITHUB_LOGIN=$(gh api user --jq '.login' 2>/dev/null)
    GITHUB_ID=$(gh api user --jq '.id' 2>/dev/null)
    
    # Use GitHub noreply email format for proper profile picture attribution
    if [ -n "$GITHUB_ID" ] && [ -n "$GITHUB_LOGIN" ]; then
        GITHUB_EMAIL="${GITHUB_ID}+${GITHUB_LOGIN}@users.noreply.github.com"
    else
        GITHUB_EMAIL="${GITHUB_LOGIN}@users.noreply.github.com"
    fi
    
    if [ -n "$GITHUB_NAME" ] && [ -n "$GITHUB_EMAIL" ]; then
        git config --global user.name "$GITHUB_NAME"
        git config --global user.email "$GITHUB_EMAIL"
        git config --global commit.gpgsign false
        echo "✅ Git user configured as: $GITHUB_NAME <$GITHUB_EMAIL>"
    else
        echo "⚠️  Could not get GitHub user info. Configure git user manually."
    fi
else
    echo "⚠️  GitHub CLI not authenticated. Configure git user manually:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
fi

# Install project dependencies and set up hooks
if [ -f "package.json" ]; then
    echo "📦 Installing project dependencies..."
    if npm install; then
        echo "✅ Project dependencies installed successfully"
    else
        echo "❌ Failed to install project dependencies"
        exit 1
    fi
    
    # Set up git hooks with modern Husky
    echo "🪝 Setting up git hooks..."
    if npx husky init; then
        echo "✅ Husky initialized successfully"
        # Remove deprecated husky.sh if it exists
        rm -f .husky/_/husky.sh
    else
        echo "⚠️  Failed to initialize Husky"
    fi
else
    echo "⚠️  No package.json found, skipping npm install"
fi

# Ensure pre-commit hook has correct content and permissions
echo "🪝 Setting up pre-commit hook..."
cat > .husky/pre-commit << 'EOF'
#!/bin/bash
echo "🧪 Running pre-commit tests..."

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

# Always run LWC tests (fast, local)
run_check "LWC unit tests" "npm run test:unit"

# Run Apex tests only if Apex files changed and org is connected
if git diff --cached --name-only | grep -qE "\.(cls|trigger)$"; then
    echo "🔍 Apex files detected in commit..."
    if sf org display --json > /dev/null 2>&1; then
        run_check "Apex tests" "npm run test:apex"
    else
        echo "⚠️  Apex files changed but no org connected."
        echo "   Please run 'sf org login web' and 'npm run test:apex' manually."
        echo "   Or skip with: git commit --no-verify"
        ERROR_MESSAGES+=("Apex tests (no org connected)")
        ERRORS=$((ERRORS + 1))
    fi
fi

# Run linting and formatting
run_check "Linting and formatting" "npx lint-staged"

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
EOF
chmod +x .husky/pre-commit

# Final setup message
echo "✅ Salesforce development environment setup complete!"
echo ""
echo "🔍 Environment validation:"
echo "  - Node.js: $(node --version)"
echo "  - npm: $(npm --version)"
echo "  - Salesforce CLI: $(sf --version | head -1)"
echo "  - Git: $(git --version)"
echo ""
echo "🎯 Next steps:"
echo "1. Authenticate with Salesforce: sf org login web"
echo "2. Set default org: sf config set target-org your-org-alias"
echo "3. Start developing!"
echo ""
echo "📚 Useful commands:"
echo "  - sf org list                    # List connected orgs"
echo "  - sf project deploy start       # Deploy to org"
echo "  - sf project retrieve start     # Pull from org"
echo "  - npm run test:unit             # Run LWC tests"
echo "  - npm run prettier              # Format code"
echo "  - sf scanner run                 # Run code analysis"
echo "  - claude-code                    # Use Claude AI assistant"
echo ""