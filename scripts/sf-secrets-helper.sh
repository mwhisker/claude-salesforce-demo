#!/usr/bin/env bash
set -euo pipefail

# Helper script to manage GitHub Codespaces Secrets for Salesforce JWT authentication
#
# Usage:
#   bash scripts/sf-secrets-helper.sh setup <alias>     # Add secrets interactively or from file
#   bash scripts/sf-secrets-helper.sh verify <alias>    # Verify secrets are set correctly
#   bash scripts/sf-secrets-helper.sh list              # List all configured aliases
#   bash scripts/sf-secrets-helper.sh export <alias>    # Export secrets as shell commands

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

prompt() {
    echo -e "${CYAN}${BOLD}[?]${NC} $1"
}

# Check for GitHub CLI
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) is not installed."
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        error "GitHub CLI is not authenticated."
        echo "Run: gh auth login"
        exit 1
    fi
}

# Setup secrets for an alias
setup_secrets() {
    local alias=$1

    if [ -z "$alias" ]; then
        error "Usage: $0 setup <alias>"
        exit 1
    fi

    check_gh_cli

    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                 GitHub Codespaces Secrets Setup                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""

    info "Setting up secrets for alias: ${alias}"
    echo ""

    # Check if secrets file exists
    secrets_file=".sf/keys/${alias}/secrets.env"

    if [ -f "$secrets_file" ]; then
        prompt "Found secrets file: ${secrets_file}. Load values from file? (yes/no)"
        read -r load_from_file

        if [ "$load_from_file" = "yes" ] || [ "$load_from_file" = "y" ]; then
            info "Loading values from ${secrets_file}..."

            # Source the file to get the values
            # shellcheck disable=SC1090
            source "$secrets_file"

            username_var="SF_JWT_USERNAME_${alias}"
            client_id_var="SF_JWT_CLIENT_ID_${alias}"
            instance_url_var="SF_JWT_INSTANCE_URL_${alias}"
            key_var="SF_JWT_KEY_${alias}"

            USERNAME="${!username_var:-}"
            CLIENT_ID="${!client_id_var:-}"
            INSTANCE_URL="${!instance_url_var:-}"
            KEY="${!key_var:-}"
        else
            load_from_file="no"
        fi
    else
        load_from_file="no"
    fi

    # Prompt for values if not loaded from file
    if [ "$load_from_file" != "yes" ] && [ "$load_from_file" != "y" ]; then
        prompt "Enter SF_JWT_USERNAME_${alias}:"
        read -r USERNAME

        prompt "Enter SF_JWT_CLIENT_ID_${alias}:"
        read -r CLIENT_ID

        prompt "Enter SF_JWT_INSTANCE_URL_${alias}:"
        read -r INSTANCE_URL

        prompt "Enter SF_JWT_KEY_${alias} (path to private.key.b64 file or paste value):"
        read -r key_input

        if [ -f "$key_input" ]; then
            KEY="$(cat "$key_input")"
        else
            KEY="$key_input"
        fi
    fi

    # Validate inputs
    if [ -z "$USERNAME" ] || [ -z "$CLIENT_ID" ] || [ -z "$INSTANCE_URL" ] || [ -z "$KEY" ]; then
        error "All values are required. Aborting."
        exit 1
    fi

    echo ""
    info "Secret values to be set:"
    echo "  SF_JWT_USERNAME_${alias}: ${USERNAME}"
    echo "  SF_JWT_CLIENT_ID_${alias}: ${CLIENT_ID:0:10}...${CLIENT_ID: -4}"
    echo "  SF_JWT_INSTANCE_URL_${alias}: ${INSTANCE_URL}"
    echo "  SF_JWT_KEY_${alias}: <base64 string, ${#KEY} characters>"
    echo ""

    # Choose secret scope
    prompt "Set secrets at which scope?"
    echo "  1) User-level (your personal Codespaces only)"
    echo "  2) Repository-level (shared across team, requires admin)"
    read -r scope_choice

    SCOPE_ARGS=""
    case $scope_choice in
        1)
            info "Setting user-level secrets..."
            SCOPE_ARGS="--app codespaces"
            ;;
        2)
            info "Setting repository-level secrets..."
            REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
            if [ -z "$REPO" ]; then
                error "Could not determine repository. Make sure you're in a git repository."
                exit 1
            fi
            SCOPE_ARGS="--app codespaces --repo ${REPO}"
            ;;
        *)
            error "Invalid choice. Aborting."
            exit 1
            ;;
    esac

    echo ""
    prompt "Proceed with setting secrets? (yes/no)"
    read -r confirm

    if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
        warn "Cancelled by user."
        exit 0
    fi

    # Set secrets
    info "Setting secrets..."

    if echo "$USERNAME" | gh secret set "SF_JWT_USERNAME_${alias}" ${SCOPE_ARGS}; then
        success "Set SF_JWT_USERNAME_${alias}"
    else
        error "Failed to set SF_JWT_USERNAME_${alias}"
    fi

    if echo "$CLIENT_ID" | gh secret set "SF_JWT_CLIENT_ID_${alias}" ${SCOPE_ARGS}; then
        success "Set SF_JWT_CLIENT_ID_${alias}"
    else
        error "Failed to set SF_JWT_CLIENT_ID_${alias}"
    fi

    if echo "$INSTANCE_URL" | gh secret set "SF_JWT_INSTANCE_URL_${alias}" ${SCOPE_ARGS}; then
        success "Set SF_JWT_INSTANCE_URL_${alias}"
    else
        error "Failed to set SF_JWT_INSTANCE_URL_${alias}"
    fi

    if echo "$KEY" | gh secret set "SF_JWT_KEY_${alias}" ${SCOPE_ARGS}; then
        success "Set SF_JWT_KEY_${alias}"
    else
        error "Failed to set SF_JWT_KEY_${alias}"
    fi

    echo ""
    success "All secrets set successfully!"
    echo ""
    info "Next steps:"
    echo "  1. Rebuild your Codespace to load the new secrets"
    echo "  2. Run 'npm run auth:jwt:diagnose' to verify configuration"
    echo "  3. Run 'npm run auth:jwt' to authenticate"
    echo ""
}

# Verify secrets are set correctly
verify_secrets() {
    local alias="${1:-}"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                  GitHub Codespaces Secrets Verification                ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""

    if [ -n "$alias" ]; then
        info "Verifying secrets for alias: ${alias}"
        verify_alias_secrets "$alias"
    else
        info "Verifying all configured aliases..."
        # Find all aliases by looking for SF_JWT_CLIENT_ID_* environment variables
        mapfile -t client_vars < <(env | grep '^SF_JWT_CLIENT_ID_' | cut -d= -f1 || true)

        if [ ${#client_vars[@]} -eq 0 ]; then
            warn "No JWT secrets found in environment."
            echo "This is expected if you haven't set up secrets yet or need to rebuild your Codespace."
            exit 0
        fi

        for var in "${client_vars[@]}"; do
            alias_name="${var#SF_JWT_CLIENT_ID_}"
            verify_alias_secrets "$alias_name"
        done
    fi

    echo ""
    success "Verification complete!"
}

# Verify secrets for a specific alias
verify_alias_secrets() {
    local alias=$1

    echo ""
    echo "Alias: ${alias}"
    echo "─────────────────────────────────────────────────────────────"

    username_var="SF_JWT_USERNAME_${alias}"
    client_id_var="SF_JWT_CLIENT_ID_${alias}"
    instance_url_var="SF_JWT_INSTANCE_URL_${alias}"
    key_var="SF_JWT_KEY_${alias}"

    username="${!username_var:-}"
    client_id="${!client_id_var:-}"
    instance_url="${!instance_url_var:-}"
    key="${!key_var:-}"

    # Check each variable
    if [ -n "$username" ]; then
        success "SF_JWT_USERNAME_${alias}: ${username}"
    else
        error "SF_JWT_USERNAME_${alias}: Not set"
    fi

    if [ -n "$client_id" ]; then
        success "SF_JWT_CLIENT_ID_${alias}: ${client_id:0:10}...${client_id: -4}"
    else
        error "SF_JWT_CLIENT_ID_${alias}: Not set"
    fi

    if [ -n "$instance_url" ]; then
        success "SF_JWT_INSTANCE_URL_${alias}: ${instance_url}"
    else
        error "SF_JWT_INSTANCE_URL_${alias}: Not set"
    fi

    if [ -n "$key" ]; then
        # Validate base64 format
        if echo "$key" | base64 -d >/dev/null 2>&1; then
            success "SF_JWT_KEY_${alias}: Valid base64 (${#key} characters)"

            # Check if it looks like a private key
            if echo "$key" | base64 -d | head -n 1 | grep -q "BEGIN.*PRIVATE KEY"; then
                success "  └─ Decoded key has valid RSA PRIVATE KEY header"
            else
                warn "  └─ Decoded key doesn't have expected RSA PRIVATE KEY header"
            fi
        else
            error "SF_JWT_KEY_${alias}: Invalid base64 encoding"
        fi
    else
        error "SF_JWT_KEY_${alias}: Not set"
    fi
}

# List all configured aliases
list_aliases() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Configured JWT Aliases                              ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Check environment variables
    mapfile -t client_vars < <(env | grep '^SF_JWT_CLIENT_ID_' | cut -d= -f1 || true)

    if [ ${#client_vars[@]} -eq 0 ]; then
        warn "No JWT secrets found in environment."
        echo ""
        echo "To set up JWT authentication:"
        echo "  1. Run: npm run auth:setup:interactive"
        echo "  2. Add secrets to GitHub Codespaces"
        echo "  3. Rebuild your Codespace"
        exit 0
    fi

    echo "Aliases found in environment:"
    echo ""

    for var in "${client_vars[@]}"; do
        alias_name="${var#SF_JWT_CLIENT_ID_}"
        username_var="SF_JWT_USERNAME_${alias_name}"
        instance_url_var="SF_JWT_INSTANCE_URL_${alias_name}"

        username="${!username_var:-<not set>}"
        instance_url="${!instance_url_var:-<not set>}"

        echo "  • ${alias_name}"
        echo "      Username: ${username}"
        echo "      Instance: ${instance_url}"
        echo ""
    done

    # Check local key files
    if [ -d ".sf/keys" ]; then
        echo "Local key files:"
        echo ""

        for key_dir in .sf/keys/*/; do
            if [ -d "$key_dir" ]; then
                alias_name=$(basename "$key_dir")
                echo "  • ${alias_name}"

                if [ -f "${key_dir}/secrets.env" ]; then
                    echo "      Config: ${key_dir}/secrets.env"
                fi

                if [ -f "${key_dir}/private.key" ]; then
                    echo "      Private key: ${key_dir}/private.key"
                fi

                if [ -f "${key_dir}/public.crt.der" ]; then
                    echo "      Public cert: ${key_dir}/public.crt.der"
                fi

                echo ""
            fi
        done
    fi
}

# Export secrets as shell commands
export_secrets() {
    local alias="${1:-}"

    if [ -z "$alias" ]; then
        error "Usage: $0 export <alias>"
        exit 1
    fi

    secrets_file=".sf/keys/${alias}/secrets.env"

    if [ ! -f "$secrets_file" ]; then
        error "Secrets file not found: ${secrets_file}"
        echo "Run 'npm run auth:setup:interactive' to generate secrets."
        exit 1
    fi

    echo ""
    echo "# Salesforce JWT Secrets for alias: ${alias}"
    echo "# Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    echo "# Copy and paste these commands to set environment variables:"
    echo ""

    # Read and output the file, but sanitize it
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi

        echo "$line"
    done < "$secrets_file"

    echo ""
    echo "# For GitHub CLI:"
    echo ""

    # shellcheck disable=SC1090
    source "$secrets_file"

    username_var="SF_JWT_USERNAME_${alias}"
    client_id_var="SF_JWT_CLIENT_ID_${alias}"
    instance_url_var="SF_JWT_INSTANCE_URL_${alias}"

    echo "gh secret set SF_JWT_USERNAME_${alias} --app codespaces --body \"${!username_var:-}\""
    echo "gh secret set SF_JWT_CLIENT_ID_${alias} --app codespaces --body \"${!client_id_var:-}\""
    echo "gh secret set SF_JWT_INSTANCE_URL_${alias} --app codespaces --body \"${!instance_url_var:-}\""
    echo "gh secret set SF_JWT_KEY_${alias} --app codespaces < .sf/keys/${alias}/private.key.b64"
    echo ""
}

# Main command routing
COMMAND="${1:-}"
ALIAS="${2:-}"

case $COMMAND in
    setup)
        setup_secrets "$ALIAS"
        ;;
    verify)
        verify_secrets "$ALIAS"
        ;;
    list)
        list_aliases
        ;;
    export)
        export_secrets "$ALIAS"
        ;;
    *)
        echo "Salesforce JWT Secrets Helper"
        echo ""
        echo "Usage:"
        echo "  $0 setup <alias>      Setup secrets for an alias (interactive)"
        echo "  $0 verify [alias]     Verify secrets are set correctly"
        echo "  $0 list               List all configured aliases"
        echo "  $0 export <alias>     Export secrets as shell commands"
        echo ""
        echo "Examples:"
        echo "  $0 setup UAT          Setup secrets for UAT alias"
        echo "  $0 verify UAT         Verify UAT secrets"
        echo "  $0 list               List all aliases"
        echo "  $0 export PROD        Export PROD secrets"
        echo ""
        exit 1
        ;;
esac
