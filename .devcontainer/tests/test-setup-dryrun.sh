#!/bin/bash
echo "🧪 Testing post-create.sh script in dry-run mode..."

# This script tests parts of the post-create script without actually modifying the system
echo "🔍 Checking prerequisites..."

# Check Node.js version
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
echo "Node.js version: $(node --version) (Major: $NODE_VERSION)"

if [ "$NODE_VERSION" -ge 20 ]; then
    echo "✅ Node.js version supports all SF CLI plugins"
else
    echo "⚠️  Node.js version may limit some SF CLI plugins"
fi

# Check if tools are available
echo ""
echo "📦 Checking available tools..."
for tool in npm git sf gh prettier eslint; do
    if command -v $tool &> /dev/null; then
        echo "✅ $tool: $(which $tool)"
    else
        echo "❌ $tool: not found"
    fi
done

# Check package.json
echo ""
echo "📋 Checking package.json structure..."
if [ -f "package.json" ]; then
    echo "✅ package.json exists"
    
    # Check for required scripts
    required_scripts=("test:unit" "lint" "prettier" "test:apex")
    for script in "${required_scripts[@]}"; do
        if npm run 2>/dev/null | grep -q "$script"; then
            echo "✅ Script '$script' found"
        else
            echo "❌ Script '$script' missing"
        fi
    done
    
    # Check for required dependencies
    required_deps=("husky" "lint-staged" "prettier" "eslint")
    for dep in "${required_deps[@]}"; do
        if npm list "$dep" >/dev/null 2>&1; then
            echo "✅ Dependency '$dep' installed"
        else
            echo "❌ Dependency '$dep' missing"
        fi
    done
else
    echo "❌ package.json not found"
fi

# Check Git configuration
echo ""
echo "🔧 Checking Git configuration..."
echo "Git user.name: $(git config --global user.name || echo 'Not set')"
echo "Git user.email: $(git config --global user.email || echo 'Not set')"
echo "Git init.defaultBranch: $(git config --global init.defaultBranch || echo 'Not set')"

# Check GitHub CLI authentication
echo ""
echo "🔐 Checking GitHub CLI authentication..."
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        echo "✅ GitHub CLI authenticated"
        echo "User: $(gh api user --jq '.login' 2>/dev/null || echo 'Unknown')"
    else
        echo "⚠️  GitHub CLI not authenticated"
    fi
else
    echo "❌ GitHub CLI not available"
fi

echo ""
echo "==================== DRY-RUN TEST SUMMARY ===================="
echo "✅ Prerequisites check completed"
echo "💡 Run actual tests with: .devcontainer/tests/test-components.sh"
echo "🔧 Test pre-commit with: .devcontainer/tests/test-precommit-hook.sh"
