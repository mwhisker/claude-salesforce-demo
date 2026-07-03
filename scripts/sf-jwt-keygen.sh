#!/usr/bin/env bash
set -euo pipefail

# Generate RSA keypair for Salesforce JWT authentication
#
# Usage:
#   bash scripts/sf-jwt-keygen.sh <alias>
#   bash scripts/sf-jwt-keygen.sh UAT
#   bash scripts/sf-jwt-keygen.sh PROD --key-size 4096
#
# Output:
#   .sf/keys/<alias>/private.key        - Private key (PEM format)
#   .sf/keys/<alias>/private.key.b64    - Base64-encoded private key
#   .sf/keys/<alias>/public.crt         - Public certificate (PEM format)
#   .sf/keys/<alias>/public.crt.der     - Public certificate (DER format for Salesforce)
#   .sf/keys/<alias>/secrets.env        - Environment variables template

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Parse arguments
ALIAS="${1:-}"
KEY_SIZE="${2:-2048}"

if [ "$KEY_SIZE" = "--key-size" ] && [ -n "${3:-}" ]; then
    KEY_SIZE="${3}"
fi

if [ -z "$ALIAS" ]; then
    error "Usage: $0 <alias> [--key-size <bits>]"
    error "Example: $0 UAT"
    error "Example: $0 PROD --key-size 4096"
    exit 1
fi

# Validate alias format (alphanumeric and underscore only)
if ! [[ "$ALIAS" =~ ^[A-Za-z0-9_]+$ ]]; then
    error "Alias must contain only alphanumeric characters and underscores"
    exit 1
fi

# Validate key size
if ! [[ "$KEY_SIZE" =~ ^(2048|4096)$ ]]; then
    error "Key size must be 2048 or 4096 bits"
    exit 1
fi

# Check for openssl
if ! command -v openssl >/dev/null 2>&1; then
    error "openssl is not installed. Please install it first."
    exit 1
fi

# Create output directory
OUTPUT_DIR=".sf/keys/${ALIAS}"
mkdir -p "$OUTPUT_DIR"

info "Generating RSA keypair for alias: ${ALIAS}"
info "Key size: ${KEY_SIZE} bits"
info "Output directory: ${OUTPUT_DIR}"

# Generate private key
PRIVATE_KEY="${OUTPUT_DIR}/private.key"
info "Generating private key..."
if ! openssl genrsa -out "$PRIVATE_KEY" "$KEY_SIZE" 2>/dev/null; then
    error "Failed to generate private key"
    exit 1
fi
chmod 600 "$PRIVATE_KEY"
success "Private key generated: ${PRIVATE_KEY}"

# Generate self-signed certificate (10-year validity)
PUBLIC_CRT="${OUTPUT_DIR}/public.crt"
info "Generating self-signed certificate..."
if ! openssl req -new -x509 -key "$PRIVATE_KEY" -out "$PUBLIC_CRT" -days 3650 \
    -subj "/C=US/ST=California/L=San Francisco/O=Development/CN=Salesforce JWT Auth ${ALIAS}" 2>/dev/null; then
    error "Failed to generate certificate"
    exit 1
fi
success "Public certificate generated: ${PUBLIC_CRT}"

# Convert certificate to DER format (required by Salesforce)
PUBLIC_CRT_DER="${OUTPUT_DIR}/public.crt.der"
info "Converting certificate to DER format..."
if ! openssl x509 -in "$PUBLIC_CRT" -outform DER -out "$PUBLIC_CRT_DER" 2>/dev/null; then
    error "Failed to convert certificate to DER format"
    exit 1
fi
success "DER certificate generated: ${PUBLIC_CRT_DER}"

# Base64-encode the private key for environment variables
PRIVATE_KEY_B64="${OUTPUT_DIR}/private.key.b64"
info "Base64-encoding private key..."
if ! base64 -w 0 < "$PRIVATE_KEY" > "$PRIVATE_KEY_B64" 2>/dev/null; then
    # macOS base64 doesn't support -w flag
    if ! base64 < "$PRIVATE_KEY" | tr -d '\n' > "$PRIVATE_KEY_B64" 2>/dev/null; then
        error "Failed to base64-encode private key"
        exit 1
    fi
fi
success "Base64-encoded private key: ${PRIVATE_KEY_B64}"

# Generate environment variables template
SECRETS_ENV="${OUTPUT_DIR}/secrets.env"
info "Generating environment variables template..."

cat > "$SECRETS_ENV" << EOF
# Salesforce JWT Authentication Environment Variables
# Generated for alias: ${ALIAS}
# Generated on: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
#
# IMPORTANT: These are templates. Fill in the missing values before use.
# DO NOT commit this file. Add .sf/ to .gitignore.

# Username of the integration user (e.g., user@example.com.sandbox)
export SF_JWT_USERNAME_${ALIAS}="YOUR_USERNAME_HERE"

# Connected App Consumer Key (retrieve after creating Connected App)
export SF_JWT_CLIENT_ID_${ALIAS}="YOUR_CONSUMER_KEY_HERE"

# Salesforce instance URL
# - Sandboxes: https://test.salesforce.com
# - Production: https://login.salesforce.com
# - My Domain: https://your-domain.my.salesforce.com
export SF_JWT_INSTANCE_URL_${ALIAS}="https://test.salesforce.com"

# Base64-encoded private key (automatically generated)
export SF_JWT_KEY_${ALIAS}="$(cat "$PRIVATE_KEY_B64")"

# Optional: Set this org as default after login (1=yes, 0=no)
export SF_JWT_SET_DEFAULT_${ALIAS}="0"

# Optional: Flag indicating the key is base64-encoded (default: 1)
export SF_JWT_KEY_IS_B64_${ALIAS}="1"
EOF

success "Environment variables template: ${SECRETS_ENV}"

# Display summary
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                   RSA Keypair Generated Successfully                   ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
info "Alias: ${ALIAS}"
info "Key Size: ${KEY_SIZE} bits"
info "Output Directory: ${OUTPUT_DIR}"
echo ""
echo "Generated Files:"
echo "  1. ${PRIVATE_KEY} (keep secret!)"
echo "  2. ${PRIVATE_KEY_B64} (for environment variables)"
echo "  3. ${PUBLIC_CRT} (PEM format)"
echo "  4. ${PUBLIC_CRT_DER} (for Salesforce Connected App)"
echo "  5. ${SECRETS_ENV} (environment variables template)"
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                            Next Steps                                  ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Create Connected App in Salesforce:"
echo "   - Setup → App Manager → New Connected App"
echo "   - Enable OAuth Settings"
echo "   - Enable 'Use digital signatures'"
echo "   - Upload certificate: ${PUBLIC_CRT_DER}"
echo "   - Select OAuth scopes: api, refresh_token, offline_access"
echo "   - Save and retrieve Consumer Key"
echo ""
echo "2. Configure OAuth Policies:"
echo "   - Edit the Connected App"
echo "   - OAuth Policies → Permitted Users: 'Admin approved users are pre-authorized'"
echo "   - IP Relaxation: 'Relax IP restrictions' (optional)"
echo "   - Save"
echo ""
echo "3. Create Permission Set:"
echo "   - Setup → Permission Sets → New"
echo "   - Add the Connected App under 'Assigned Connected Apps'"
echo "   - Assign the Permission Set to your integration user"
echo ""
echo "4. Update environment variables template:"
echo "   - Edit: ${SECRETS_ENV}"
echo "   - Fill in SF_JWT_USERNAME_${ALIAS}"
echo "   - Fill in SF_JWT_CLIENT_ID_${ALIAS} (from Connected App)"
echo "   - Update SF_JWT_INSTANCE_URL_${ALIAS} if needed"
echo ""
echo "5. Add secrets to GitHub Codespaces:"
echo "   Option A: Via GitHub UI"
echo "     - Go to: Settings → Codespaces → Secrets"
echo "     - Add each SF_JWT_* variable"
echo ""
echo "   Option B: Via GitHub CLI"
echo "     gh secret set SF_JWT_USERNAME_${ALIAS} --app codespaces --body \"YOUR_USERNAME\""
echo "     gh secret set SF_JWT_CLIENT_ID_${ALIAS} --app codespaces --body \"YOUR_CONSUMER_KEY\""
echo "     gh secret set SF_JWT_INSTANCE_URL_${ALIAS} --app codespaces --body \"https://test.salesforce.com\""
echo "     gh secret set SF_JWT_KEY_${ALIAS} --app codespaces < ${PRIVATE_KEY_B64}"
echo ""
echo "6. Test authentication:"
echo "   npm run auth:jwt:diagnose   # Validate configuration"
echo "   npm run auth:jwt             # Authenticate"
echo ""
warn "SECURITY REMINDER:"
echo "  - Never commit private keys to version control"
echo "  - Keep .sf/keys/ in .gitignore"
echo "  - Rotate keys quarterly for production orgs"
echo "  - Use separate keys for each developer"
echo ""

# Certificate information
info "Certificate Details:"
openssl x509 -in "$PUBLIC_CRT" -noout -subject -dates -fingerprint -sha256 2>/dev/null || true
echo ""

success "Setup complete! Follow the next steps above to complete authentication setup."
