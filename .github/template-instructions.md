# Salesforce Development Template

## Creating a New Salesforce Project

1. **Create new repository from this template:**
    - Click "Use this template" button on GitHub
    - Name your new Salesforce project
    - Choose public/private visibility

2. **Open in Codespace:**
    - Go to your new repository
    - Click "Code" → "Codespaces" → "Create codespace on main"
    - Wait for devcontainer to build (3-5 minutes)

3. **Initialize Salesforce project:**

    ```bash
    # Remove template files (optional)
    rm -rf .github/template-instructions.md

    # Create new SFDX project (if starting fresh)
    sf project generate --name MyProject

    # Or clone existing Salesforce project
    git clone <your-salesforce-repo-url> .
    ```

4. **Authenticate with Salesforce:**
    ```bash
    sf org login web --alias myorg
    sf config set target-org myorg
    ```

## What's Included

- Pre-configured VS Code extensions for Salesforce
- Salesforce CLI with common plugins
- Node.js development tools
- Prettier and ESLint configuration
- Common Salesforce development dependencies
