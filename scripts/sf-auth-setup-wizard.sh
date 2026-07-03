#!/usr/bin/env bash
set -euo pipefail

# Interactive wizard for setting up Salesforce JWT authentication
#
# Usage:
#   bash scripts/sf-auth-setup-wizard.sh
#   npm run auth:setup:interactive
#
#   bash scripts/sf-auth-setup-wizard.sh --from-template
#   npm run auth:setup:from-template

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

# Check if running in from-template mode
FROM_TEMPLATE=false
if [ "${1:-}" = "--from-template" ]; then
    FROM_TEMPLATE=true
fi

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║         Salesforce JWT Authentication Setup Wizard                    ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$FROM_TEMPLATE" = true ]; then
    info "Mode: Setup from existing Connected App template"
    echo ""
    echo "This wizard will help you set up authentication to a Salesforce org"
    echo "that already has a Connected App configured for JWT authentication."
    echo ""
    echo "You will need:"
    echo "  - The Connected App's Consumer Key"
    echo "  - Your integration user's username"
    echo "  - The org's instance URL"
    echo ""
else
    info "Mode: Full setup (new Connected App)"
    echo ""
    echo "This wizard will help you set up JWT authentication to a Salesforce org."
    echo "It will generate RSA keypairs and guide you through Connected App setup."
    echo ""
    echo "You will need:"
    echo "  - Access to Salesforce Setup (System Administrator profile)"
    echo "  - An integration user with API access"
    echo "  - 10-15 minutes to complete the setup"
    echo ""
fi

# Prompt to continue
read -p "Press Enter to continue or Ctrl+C to cancel... "
echo ""

# Step 1: Collect org information
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                        Step 1: Org Information                         ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# Alias
while true; do
    prompt "Enter an alias for this org (alphanumeric, e.g., UAT, PROD, DEV):"
    read -r ALIAS

    if [ -z "$ALIAS" ]; then
        error "Alias cannot be empty"
        continue
    fi

    if ! [[ "$ALIAS" =~ ^[A-Za-z0-9_]+$ ]]; then
        error "Alias must contain only alphanumeric characters and underscores"
        continue
    fi

    # Check if alias already exists
    if [ -d ".sf/keys/${ALIAS}" ]; then
        warn "Keys already exist for alias '${ALIAS}'"
        prompt "Overwrite existing keys? (yes/no)"
        read -r overwrite
        if [ "$overwrite" != "yes" ] && [ "$overwrite" != "y" ]; then
            continue
        fi
    fi

    break
done
echo ""

# Instance URL
while true; do
    prompt "Enter the Salesforce instance URL:"
    echo "  1) https://test.salesforce.com (Sandboxes)"
    echo "  2) https://login.salesforce.com (Production)"
    echo "  3) Custom (My Domain)"
    read -r url_choice

    case $url_choice in
        1)
            INSTANCE_URL="https://test.salesforce.com"
            break
            ;;
        2)
            INSTANCE_URL="https://login.salesforce.com"
            break
            ;;
        3)
            prompt "Enter your My Domain URL (e.g., https://mycompany.my.salesforce.com):"
            read -r INSTANCE_URL

            if [ -z "$INSTANCE_URL" ]; then
                error "Instance URL cannot be empty"
                continue
            fi

            if ! [[ "$INSTANCE_URL" =~ ^https:// ]]; then
                error "Instance URL must start with https://"
                continue
            fi

            break
            ;;
        *)
            error "Invalid choice. Please select 1, 2, or 3."
            ;;
    esac
done
echo ""

# Integration username
while true; do
    prompt "Enter the integration user's username (e.g., integration@company.com.sandbox):"
    read -r USERNAME

    if [ -z "$USERNAME" ]; then
        error "Username cannot be empty"
        continue
    fi

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        warn "Username doesn't look like an email address. Continue anyway? (yes/no)"
        read -r continue_username
        if [ "$continue_username" != "yes" ] && [ "$continue_username" != "y" ]; then
            continue
        fi
    fi

    break
done
echo ""

# Step 2: Generate or import keypair
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                      Step 2: Generate Keypair                          ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$FROM_TEMPLATE" = true ]; then
    prompt "Do you have an existing private key to import? (yes/no)"
    read -r has_existing_key

    if [ "$has_existing_key" = "yes" ] || [ "$has_existing_key" = "y" ]; then
        prompt "Enter the path to your existing private key (PEM format):"
        read -r existing_key_path

        if [ ! -f "$existing_key_path" ]; then
            error "File not found: $existing_key_path"
            error "Continuing with new key generation..."
            has_existing_key="no"
        else
            # Copy existing key
            mkdir -p ".sf/keys/${ALIAS}"
            cp "$existing_key_path" ".sf/keys/${ALIAS}/private.key"
            chmod 600 ".sf/keys/${ALIAS}/private.key"
            success "Imported existing private key"

            # Generate certificate from existing key
            info "Generating certificate from existing key..."
            openssl req -new -x509 -key ".sf/keys/${ALIAS}/private.key" \
                -out ".sf/keys/${ALIAS}/public.crt" -days 3650 \
                -subj "/C=US/ST=California/L=San Francisco/O=Development/CN=Salesforce JWT Auth ${ALIAS}" 2>/dev/null

            # Generate DER format
            openssl x509 -in ".sf/keys/${ALIAS}/public.crt" -outform DER \
                -out ".sf/keys/${ALIAS}/public.crt.der" 2>/dev/null

            # Base64 encode
            if base64 -w 0 < ".sf/keys/${ALIAS}/private.key" > ".sf/keys/${ALIAS}/private.key.b64" 2>/dev/null; then
                :
            else
                base64 < ".sf/keys/${ALIAS}/private.key" | tr -d '\n' > ".sf/keys/${ALIAS}/private.key.b64"
            fi

            success "Certificate generated from existing key"
        fi
    fi

    if [ "$has_existing_key" != "yes" ] && [ "$has_existing_key" != "y" ]; then
        info "Generating new RSA keypair..."
        bash scripts/sf-jwt-keygen.sh "$ALIAS" 2>&1 | grep -v "^\[" || true
        success "Keypair generated successfully"
    fi
else
    # Key size selection
    prompt "Select RSA key size:"
    echo "  1) 2048 bits (standard, recommended)"
    echo "  2) 4096 bits (maximum security)"
    read -r key_size_choice

    case $key_size_choice in
        1)
            KEY_SIZE=2048
            ;;
        2)
            KEY_SIZE=4096
            ;;
        *)
            warn "Invalid choice. Using default: 2048 bits"
            KEY_SIZE=2048
            ;;
    esac

    info "Generating RSA keypair (${KEY_SIZE} bits)..."
    bash scripts/sf-jwt-keygen.sh "$ALIAS" --key-size "$KEY_SIZE" 2>&1 | grep -v "Next Steps" -A 999 | head -n -1 || true
    success "Keypair generated successfully"
fi
echo ""

# Step 3: Connected App setup
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                   Step 3: Connected App Setup                          ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$FROM_TEMPLATE" = true ]; then
    # Import existing Connected App Consumer Key
    while true; do
        prompt "Enter the Connected App's Consumer Key:"
        read -r CONSUMER_KEY

        if [ -z "$CONSUMER_KEY" ]; then
            error "Consumer Key cannot be empty"
            continue
        fi

        if [ ${#CONSUMER_KEY} -lt 20 ]; then
            warn "Consumer Key seems too short. Continue anyway? (yes/no)"
            read -r continue_key
            if [ "$continue_key" != "yes" ] && [ "$continue_key" != "y" ]; then
                continue
            fi
        fi

        break
    done
    echo ""

    info "Please ensure the following in Salesforce:"
    echo "  1. The Connected App has your public certificate uploaded"
    echo "     Certificate location: .sf/keys/${ALIAS}/public.crt.der"
    echo "  2. OAuth policies are set to 'Admin approved users are pre-authorized'"
    echo "  3. You have a Permission Set with the Connected App enabled"
    echo "  4. The integration user is assigned to that Permission Set"
    echo ""

    prompt "Have you completed these steps? (yes/no)"
    read -r completed_steps

    if [ "$completed_steps" != "yes" ] && [ "$completed_steps" != "y" ]; then
        warn "Please complete the steps above before continuing."
        echo ""
        echo "Certificate to upload: .sf/keys/${ALIAS}/public.crt.der"
        echo ""
        exit 1
    fi
else
    # Guide user through manual Connected App creation
    info "You need to create a Connected App in Salesforce."
    echo ""
    echo "Follow these steps:"
    echo ""
    echo "1. In Salesforce Setup, navigate to: App Manager"
    echo "   (Setup → Apps → App Manager)"
    echo ""
    echo "2. Click 'New Connected App'"
    echo ""
    echo "3. Fill in basic information:"
    echo "   - Connected App Name: JWT Auth Integration ${ALIAS}"
    echo "   - API Name: JWT_Auth_Integration_${ALIAS}"
    echo "   - Contact Email: your.email@example.com"
    echo ""
    echo "4. Enable OAuth Settings:"
    echo "   - Check 'Enable OAuth Settings'"
    echo "   - Callback URL: https://login.salesforce.com/services/oauth2/success"
    echo "   - Check 'Use digital signatures'"
    echo "   - Upload certificate: $(pwd)/.sf/keys/${ALIAS}/public.crt.der"
    echo ""
    echo "5. Select OAuth Scopes:"
    echo "   - Access and manage your data (api)"
    echo "   - Perform requests on your behalf at any time (refresh_token, offline_access)"
    echo ""
    echo "6. Click 'Save'"
    echo ""
    echo "7. Click 'Continue' on the confirmation page"
    echo ""
    echo "8. Click 'Manage Consumer Details' to view the Consumer Key"
    echo "   (You may need to verify your identity)"
    echo ""

    prompt "Press Enter once you have the Consumer Key ready..."
    read -r

    while true; do
        prompt "Enter the Consumer Key from the Connected App:"
        read -r CONSUMER_KEY

        if [ -z "$CONSUMER_KEY" ]; then
            error "Consumer Key cannot be empty"
            continue
        fi

        break
    done
    echo ""

    info "Additional configuration required in Salesforce:"
    echo ""
    echo "9. Edit the Connected App:"
    echo "   - Setup → App Manager → JWT Auth Integration ${ALIAS} → Manage"
    echo "   - Click 'Edit Policies'"
    echo "   - Permitted Users: 'Admin approved users are pre-authorized'"
    echo "   - IP Relaxation: 'Relax IP restrictions' (optional, for development)"
    echo "   - Click 'Save'"
    echo ""
    echo "10. Create a Permission Set:"
    echo "   - Setup → Permission Sets → New"
    echo "   - Label: JWT Auth ${ALIAS} Users"
    echo "   - Click 'Save'"
    echo "   - Go to: Assigned Connected Apps → Add"
    echo "   - Select: JWT Auth Integration ${ALIAS}"
    echo "   - Click 'Save'"
    echo ""
    echo "11. Assign Permission Set to integration user:"
    echo "   - Setup → Users → ${USERNAME}"
    echo "   - Permission Set Assignments → Add Assignment"
    echo "   - Select: JWT Auth ${ALIAS} Users"
    echo "   - Click 'Assign'"
    echo ""

    prompt "Press Enter once you have completed these steps..."
    read -r
fi
echo ""

# Step 4: Generate environment variables
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                 Step 4: Environment Variables                          ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

SECRETS_ENV=".sf/keys/${ALIAS}/secrets.env"

# Update the secrets.env file with actual values
cat > "$SECRETS_ENV" << EOF
# Salesforce JWT Authentication Environment Variables
# Generated for alias: ${ALIAS}
# Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

export SF_JWT_USERNAME_${ALIAS}="${USERNAME}"
export SF_JWT_CLIENT_ID_${ALIAS}="${CONSUMER_KEY}"
export SF_JWT_INSTANCE_URL_${ALIAS}="${INSTANCE_URL}"
export SF_JWT_KEY_${ALIAS}="$(cat ".sf/keys/${ALIAS}/private.key.b64")"
export SF_JWT_SET_DEFAULT_${ALIAS}="0"
export SF_JWT_KEY_IS_B64_${ALIAS}="1"
EOF

success "Environment variables saved to: ${SECRETS_ENV}"
echo ""

# Step 5: Test authentication locally
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                    Step 5: Test Authentication                         ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

prompt "Test authentication now? (yes/no)"
read -r test_now

if [ "$test_now" = "yes" ] || [ "$test_now" = "y" ]; then
    info "Loading environment variables..."
    # shellcheck disable=SC1090
    source "$SECRETS_ENV"

    info "Running diagnose mode..."
    if npm run auth:jwt:diagnose 2>&1 | grep -A 5 "\[OK\].*${ALIAS}"; then
        success "Configuration validated successfully"
        echo ""

        prompt "Attempt live authentication? (yes/no)"
        read -r auth_now

        if [ "$auth_now" = "yes" ] || [ "$auth_now" = "y" ]; then
            info "Authenticating..."
            if ONLY_ALIAS="$ALIAS" npm run auth:jwt; then
                success "Authentication successful!"
                echo ""
                sf org display -o "$ALIAS" || true
            else
                error "Authentication failed. Please check the following:"
                echo "  - Is the integration user active?"
                echo "  - Is the Permission Set assigned correctly?"
                echo "  - Is the certificate uploaded to the Connected App?"
                echo "  - Are the OAuth policies configured correctly?"
                echo ""
                echo "Run 'npm run auth:jwt:diagnose' for more details."
            fi
        fi
    else
        error "Configuration validation failed. Please check your inputs."
    fi
fi
echo ""

# Step 6: GitHub Codespaces Secrets
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                Step 6: GitHub Codespaces Secrets                       ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

info "To use this authentication in GitHub Codespaces, add these secrets:"
echo ""

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    info "GitHub CLI is authenticated. You can add secrets with these commands:"
    echo ""
    echo "# User-level secrets (for your personal Codespaces):"
    echo "gh secret set SF_JWT_USERNAME_${ALIAS} --app codespaces --body \"${USERNAME}\""
    echo "gh secret set SF_JWT_CLIENT_ID_${ALIAS} --app codespaces --body \"${CONSUMER_KEY}\""
    echo "gh secret set SF_JWT_INSTANCE_URL_${ALIAS} --app codespaces --body \"${INSTANCE_URL}\""
    echo "gh secret set SF_JWT_KEY_${ALIAS} --app codespaces < .sf/keys/${ALIAS}/private.key.b64"
    echo ""
    echo "# Repository-level secrets (shared across team, requires admin access):"
    echo "gh secret set SF_JWT_CLIENT_ID_${ALIAS} --app codespaces --repo \$(gh repo view --json nameWithOwner -q .nameWithOwner) --body \"${CONSUMER_KEY}\""
    echo "gh secret set SF_JWT_INSTANCE_URL_${ALIAS} --app codespaces --repo \$(gh repo view --json nameWithOwner -q .nameWithOwner) --body \"${INSTANCE_URL}\""
    echo ""

    prompt "Add user-level secrets now? (yes/no)"
    read -r add_secrets

    if [ "$add_secrets" = "yes" ] || [ "$add_secrets" = "y" ]; then
        info "Adding secrets to GitHub Codespaces..."

        gh secret set "SF_JWT_USERNAME_${ALIAS}" --app codespaces --body "${USERNAME}" && \
            success "Set SF_JWT_USERNAME_${ALIAS}" || error "Failed to set SF_JWT_USERNAME_${ALIAS}"

        gh secret set "SF_JWT_CLIENT_ID_${ALIAS}" --app codespaces --body "${CONSUMER_KEY}" && \
            success "Set SF_JWT_CLIENT_ID_${ALIAS}" || error "Failed to set SF_JWT_CLIENT_ID_${ALIAS}"

        gh secret set "SF_JWT_INSTANCE_URL_${ALIAS}" --app codespaces --body "${INSTANCE_URL}" && \
            success "Set SF_JWT_INSTANCE_URL_${ALIAS}" || error "Failed to set SF_JWT_INSTANCE_URL_${ALIAS}"

        gh secret set "SF_JWT_KEY_${ALIAS}" --app codespaces < ".sf/keys/${ALIAS}/private.key.b64" && \
            success "Set SF_JWT_KEY_${ALIAS}" || error "Failed to set SF_JWT_KEY_${ALIAS}"

        echo ""
        success "Secrets added to GitHub Codespaces!"
        info "You can now rebuild your Codespace to use these secrets."
    fi
else
    info "Add secrets via GitHub UI:"
    echo ""
    echo "1. Go to: https://github.com/settings/codespaces"
    echo "2. Under 'Codespaces secrets', click 'New secret'"
    echo "3. Add the following secrets:"
    echo ""
    echo "   Name: SF_JWT_USERNAME_${ALIAS}"
    echo "   Value: ${USERNAME}"
    echo ""
    echo "   Name: SF_JWT_CLIENT_ID_${ALIAS}"
    echo "   Value: ${CONSUMER_KEY}"
    echo ""
    echo "   Name: SF_JWT_INSTANCE_URL_${ALIAS}"
    echo "   Value: ${INSTANCE_URL}"
    echo ""
    echo "   Name: SF_JWT_KEY_${ALIAS}"
    echo "   Value: (copy from .sf/keys/${ALIAS}/private.key.b64)"
    echo ""
fi
echo ""

# Final summary
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                          Setup Complete!                               ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

success "JWT authentication setup completed for alias: ${ALIAS}"
echo ""
echo "Summary:"
echo "  - Alias: ${ALIAS}"
echo "  - Username: ${USERNAME}"
echo "  - Instance URL: ${INSTANCE_URL}"
echo "  - Private key: .sf/keys/${ALIAS}/private.key"
echo "  - Public certificate: .sf/keys/${ALIAS}/public.crt.der"
echo "  - Environment variables: ${SECRETS_ENV}"
echo ""
echo "Next steps:"
echo "  1. Add secrets to GitHub Codespaces (see above)"
echo "  2. Rebuild your Codespace to load the secrets"
echo "  3. Authentication will happen automatically on startup"
echo ""
echo "Useful commands:"
echo "  npm run auth:jwt:diagnose    # Validate configuration"
echo "  npm run auth:jwt              # Authenticate manually"
echo "  sf org list                   # List authenticated orgs"
echo "  sf org display -o ${ALIAS}    # View org details"
echo ""

warn "SECURITY REMINDER:"
echo "  - Never commit files in .sf/keys/ to version control"
echo "  - Rotate keys quarterly for production orgs"
echo "  - Use separate keys for each developer"
echo ""
