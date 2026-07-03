#!/usr/bin/env bash
set -euo pipefail

# Wrapper script for automated Connected App creation
#
# Usage:
#   bash scripts/sf-connected-app-create.sh <alias> <email> [org-alias]
#   npm run connected-app:create <alias> <email> [org-alias]

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check arguments
if [ $# -lt 2 ]; then
    error "Usage: $0 <alias> <email> [org-alias]"
    echo ""
    echo "Arguments:"
    echo "  alias      - Org alias (e.g., UAT, PROD)"
    echo "  email      - Contact email for Connected App"
    echo "  org-alias  - (Optional) Authenticated Salesforce org alias"
    echo ""
    echo "Examples:"
    echo "  $0 UAT admin@example.com"
    echo "  $0 PROD admin@example.com my-prod-org"
    echo ""
    echo "Prerequisites:"
    echo "  1. Authenticate to Salesforce: sf org login web --alias <org>"
    echo "  2. Install dependencies: npm install"
    exit 1
fi

ALIAS="$1"
EMAIL="$2"
ORG_ALIAS="${3:-}"

# Check if Node.js is available
if ! command -v node >/dev/null 2>&1; then
    error "Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if dependencies are installed
if [ ! -d "node_modules/jsforce" ]; then
    warn "Dependencies not found. Installing..."
    npm install
fi

# Check if authenticated to Salesforce
if [ -n "$ORG_ALIAS" ]; then
    if ! sf org display -o "$ORG_ALIAS" >/dev/null 2>&1; then
        error "Not authenticated to org: $ORG_ALIAS"
        echo "Run: sf org login web --alias $ORG_ALIAS"
        exit 1
    fi
else
    if ! sf org display >/dev/null 2>&1; then
        error "Not authenticated to any Salesforce org"
        echo "Run: sf org login web --alias <org>"
        exit 1
    fi
fi

# Check if keypair exists for this alias
CERT_PATH=""
if [ -f ".sf/keys/${ALIAS}/public.crt.der" ]; then
    info "Found existing certificate for alias: ${ALIAS}"
    CERT_PATH=".sf/keys/${ALIAS}/public.crt.der"
else
    warn "No certificate found for alias: ${ALIAS}"
    echo "Generate one with: npm run auth:keygen ${ALIAS}"
    echo ""
    read -p "Continue without certificate? (yes/no): " continue_without_cert
    if [ "$continue_without_cert" != "yes" ] && [ "$continue_without_cert" != "y" ]; then
        exit 0
    fi
fi

# Get integration username if available
USERNAME=""
if [ -f ".sf/keys/${ALIAS}/secrets.env" ]; then
    # shellcheck disable=SC1090
    source ".sf/keys/${ALIAS}/secrets.env"
    username_var="SF_JWT_USERNAME_${ALIAS}"
    USERNAME="${!username_var:-}"
    if [ -n "$USERNAME" ]; then
        info "Found integration username: ${USERNAME}"
    fi
fi

# Build node command
NODE_CMD="node scripts/lib/connected-app-automation.js --alias \"$ALIAS\" --email \"$EMAIL\""

if [ -n "$ORG_ALIAS" ]; then
    NODE_CMD="$NODE_CMD --org \"$ORG_ALIAS\""
fi

if [ -n "$CERT_PATH" ]; then
    NODE_CMD="$NODE_CMD --cert \"$CERT_PATH\""
fi

if [ -n "$USERNAME" ]; then
    NODE_CMD="$NODE_CMD --username \"$USERNAME\""
fi

# Execute
info "Creating Connected App for alias: ${ALIAS}"
eval "$NODE_CMD"
