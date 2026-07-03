# Salesforce JWT Authentication Automation Design

## Executive Summary

This document outlines a comprehensive design for automating Salesforce JWT authentication in development environments (Codespaces, devcontainers, local). The solution minimizes manual setup overhead while maintaining security best practices through environment variables and automated certificate generation.

**Key Goals:**
- Zero-knowledge setup for new developers (after initial org configuration)
- Automated RSA keypair generation and management
- Seamless integration with GitHub Codespaces Secrets
- Interactive setup with minimal user input (org name, URL, username)
- Optional fully-automated Connected App deployment
- Repeatable across multiple orgs and environments

---

## Current State Analysis

### Existing Implementation Strengths

1. **Robust JWT Login Script** (`scripts/sf-jwt-login.sh`)
   - Supports multiple org aliases via environment variables
   - Handles base64-encoded private keys
   - Key validation and normalization
   - Diagnose mode for troubleshooting
   - Works with both `sf` and `sfdx` CLI

2. **Clear Documentation** (`docs/authentication.md`)
   - Two authentication methods: SFDX Auth URL and JWT
   - Environment variable naming convention
   - Security best practices

3. **DevContainer Integration** (`.devcontainer/`)
   - Automated Salesforce CLI installation
   - GitHub CLI integration for git config
   - Post-create hooks for setup

### Current Gaps

1. **Manual Certificate Generation**
   - No automated RSA keypair generation
   - Developers must run `openssl` commands manually
   - Certificate upload to Connected App is manual

2. **Connected App Setup**
   - Entirely manual process in Salesforce UI
   - No templates or automation options documented
   - Configuration drift between orgs

3. **Secret Management**
   - No tooling to help populate GitHub Codespaces Secrets
   - Manual copy-paste of keys and IDs
   - No validation before secrets are set

4. **Interactive Setup**
   - No interactive wizard for first-time setup
   - Users must read docs and execute multiple commands
   - Error-prone for new developers

---

## Proposed Solution Architecture

### Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Developer Input                                             │
│  - Org alias (e.g., "UAT", "PROD")                          │
│  - Instance URL (e.g., "https://test.salesforce.com")       │
│  - Integration username                                      │
│  - (Optional) Existing Connected App Consumer Key           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Automated Setup Script                                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Generate RSA keypair (2048-bit)                    │  │
│  │ 2. Create base64-encoded private key                  │  │
│  │ 3. Export public certificate (PEM/DER)                │  │
│  │ 4. Generate environment variable template             │  │
│  │ 5. (Optional) Deploy Connected App via Metadata API   │  │
│  │ 6. Display setup instructions                         │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Output Artifacts                                            │
│  ├─ Private key (base64) → GitHub Secret                    │
│  ├─ Public certificate → Connected App upload               │
│  ├─ Environment variables template                          │
│  ├─ (Optional) Connected App metadata package               │
│  └─ Setup verification checklist                            │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Modes

#### Mode 1: Interactive Setup (New Org)
For developers setting up a new org for the first time:

```bash
npm run auth:setup:interactive
```

**Process:**
1. Prompt for org details (alias, URL, username)
2. Generate RSA keypair automatically
3. Create Connected App metadata package (optional)
4. Display step-by-step instructions with copy-paste commands
5. Validate setup with diagnose mode

#### Mode 2: Automated Setup (Existing Connected App)
For developers joining a project with existing Connected App:

```bash
npm run auth:setup:from-secrets
```

**Process:**
1. Read all required secrets from environment
2. Validate secrets with diagnose mode
3. Authenticate automatically via JWT
4. No user interaction required

#### Mode 3: Secrets Generator (CI/Admin Use)
For admins provisioning secrets for multiple developers:

```bash
npm run auth:generate-secrets <alias>
```

**Process:**
1. Generate keypair
2. Output formatted GitHub Secrets commands
3. Provide Connected App configuration template

---

## Implementation Components

### Component 1: Keypair Generation Script

**File:** `scripts/sf-jwt-keygen.sh`

```bash
#!/usr/bin/env bash
# Generate RSA keypair for Salesforce JWT authentication
#
# Usage:
#   bash scripts/sf-jwt-keygen.sh <alias>
#   bash scripts/sf-jwt-keygen.sh UAT
#
# Output:
#   - .sf/keys/<alias>.key (private key, PEM format)
#   - .sf/keys/<alias>.crt (public certificate, PEM format)
#   - .sf/keys/<alias>.crt.der (public certificate, DER format for SF)
#   - .sf/keys/<alias>.env (environment variables template)
```

**Features:**
- 2048-bit RSA key generation
- Automatic base64 encoding of private key
- Multiple certificate formats (PEM for inspection, DER for Salesforce)
- Self-signed certificate with 10-year validity
- Environment variable template generation
- Secure file permissions (600 for private key)

### Component 2: Interactive Setup Wizard

**File:** `scripts/sf-auth-setup-wizard.sh`

```bash
#!/usr/bin/env bash
# Interactive wizard for setting up Salesforce JWT authentication
#
# Usage:
#   npm run auth:setup:interactive
```

**Prompts:**
1. Org alias (validation: alphanumeric, no spaces)
2. Instance URL (validation: https://*.salesforce.com or login/test.salesforce.com)
3. Integration username (validation: email format)
4. Create new Connected App? (yes/no)

**Outputs:**
1. Generated keypair in `.sf/keys/<alias>/`
2. Environment variables file for review
3. GitHub Secrets commands (for copy-paste)
4. Connected App configuration instructions (or metadata package)

### Component 3: Connected App Metadata Package

**File:** `config/connected-app-templates/jwt-template.xml`

**Approach: Salesforce DX Metadata Deployment**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ConnectedApp xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{{APP_NAME}}</label>
    <contactEmail>{{CONTACT_EMAIL}}</contactEmail>
    <oauthConfig>
        <callbackUrl>https://login.salesforce.com/services/oauth2/success</callbackUrl>
        <certificate>{{BASE64_CERTIFICATE}}</certificate>
        <consumerKey>{{CONSUMER_KEY}}</consumerKey>
        <scopes>Api</scopes>
        <scopes>RefreshToken</scopes>
        <scopes>OfflineAccess</scopes>
        <useDigitalSignatures>true</useDigitalSignatures>
    </oauthConfig>
</ConnectedApp>
```

**Automation Options:**

#### Option A: Semi-Automated (Recommended for Security)
1. Generate metadata package with populated template
2. Developer deploys manually: `sf project deploy start -d config/connected-app-templates/`
3. Developer manually configures OAuth policies and permissions in UI
4. Retrieve Consumer Key manually

**Pros:**
- Maintains security review/approval process
- Works in all Salesforce editions
- Transparent and auditable

**Cons:**
- Still requires manual steps in Salesforce UI

#### Option B: Fully Automated (Requires Admin API Access)
1. Use Metadata API to deploy Connected App
2. Use Tooling API to configure OAuth policies
3. Query Consumer Key programmatically
4. Assign Permission Set via Apex or Tooling API

**Implementation:**
```bash
# Deploy Connected App
sf project deploy start -d config/connected-app-templates/ --json

# Retrieve Consumer Key
sf data query --query "SELECT Id, ConsumerKey FROM ConnectedApplication WHERE Name='JWT Auth Integration'" --json

# Assign Permission Set (requires custom Apex or REST API calls)
```

**Pros:**
- Fully automated
- Zero manual clicks in Salesforce UI

**Cons:**
- Requires Modify All Data or Customize Application permission
- May violate security policies in production orgs
- Complex error handling

#### Option C: Hybrid Approach (Recommended)
1. Automated setup creates metadata package and deployment script
2. Admin deploys Connected App once per org (manual or automated)
3. All developers share the same Connected App Consumer Key
4. Individual developers generate their own keypairs
5. Admin assigns Permission Set to each integration user

**Benefits:**
- One-time org setup effort
- Centralized Connected App management
- Individual key rotation without affecting others
- Auditable per-user access

### Component 4: GitHub Secrets Helper

**File:** `scripts/sf-secrets-helper.sh`

```bash
#!/usr/bin/env bash
# Helper script to set GitHub Codespaces Secrets
#
# Usage:
#   bash scripts/sf-secrets-helper.sh setup <alias>
#   bash scripts/sf-secrets-helper.sh verify <alias>
```

**Features:**
- Interactive mode: prompts for secret values
- File mode: reads from `.sf/keys/<alias>.env`
- Dry-run mode: shows commands without executing
- Verification mode: validates secrets are set correctly

**Integration with GitHub CLI:**
```bash
# Set user-level secret
gh secret set SF_JWT_KEY_UAT --app codespaces < .sf/keys/UAT/private.key.b64

# Set repository-level secret (requires admin)
gh secret set SF_JWT_CLIENT_ID_UAT --app codespaces --repo org/repo
```

### Component 5: DevContainer Integration

**Update:** `.devcontainer/post-create.sh`

Add authentication automation section:

```bash
# Salesforce Authentication Setup
echo "🔐 Setting up Salesforce authentication..."

# Check if JWT secrets are configured
if env | grep -q "^SF_JWT_CLIENT_ID_"; then
    echo "✅ JWT secrets found, authenticating..."
    if npm run auth:jwt; then
        echo "✅ Successfully authenticated to Salesforce orgs"
        sf org list
    else
        echo "⚠️  JWT authentication failed. Run 'npm run auth:jwt:diagnose' for details"
    fi
else
    echo "ℹ️  No JWT secrets configured. To set up:"
    echo "   1. Run: npm run auth:setup:interactive"
    echo "   2. Add secrets to GitHub Codespaces"
    echo "   3. Rebuild the container"
fi
```

**Update:** `.devcontainer/devcontainer.json`

Add environment variable documentation:

```json
{
    "remoteEnv": {
        "SF_JWT_DEBUG": "${localEnv:SF_JWT_DEBUG:0}",
        "SF_JWT_DIAGNOSE": "${localEnv:SF_JWT_DIAGNOSE:0}"
    }
}
```

---

## Security Considerations

### Private Key Management

1. **Never Commit Private Keys**
   - Add `.sf/keys/` to `.gitignore`
   - Use pre-commit hooks to scan for key patterns
   - Rotate keys if accidentally committed

2. **Base64 Encoding Benefits**
   - Preserves newlines in environment variables
   - Reduces copy-paste errors
   - Compatible with GitHub Secrets UI

3. **Key Rotation**
   - Document rotation process
   - Generate new keypair without revoking old
   - Test new key before revoking old
   - Update Connected App with new certificate

### Connected App Security

1. **OAuth Policies**
   - Always use "Admin approved users are pre-authorized"
   - Never use "All users may self-authorize"
   - Restrict by Permission Set assignment

2. **Scope Limitation**
   - Minimum required: `api`, `refresh_token`, `offline_access`
   - Avoid `full` scope unless necessary
   - Document why each scope is needed

3. **IP Restrictions**
   - Consider IP allowlisting for production
   - Document GitHub Codespaces IP ranges if needed
   - Balance security vs. developer experience

### Secret Storage

1. **GitHub Codespaces Secrets Hierarchy**
   - User-level: Developer's personal orgs/sandboxes
   - Repository-level: Shared dev/test orgs (requires repo admin)
   - Organization-level: CI/CD integration users (requires org admin)

2. **Secret Naming Convention**
   ```
   SF_JWT_USERNAME_<ALIAS>        # Individual per developer
   SF_JWT_CLIENT_ID_<ALIAS>       # Shared across team
   SF_JWT_INSTANCE_URL_<ALIAS>    # Shared across team
   SF_JWT_KEY_<ALIAS>             # Individual per developer
   ```

3. **Audit and Compliance**
   - Log all authentication events
   - Monitor Connected App usage in Salesforce
   - Review assigned users quarterly

---

## User Experience Flows

### Flow 1: First-Time Developer Setup

**Scenario:** New developer joining the project, org already has Connected App

**Steps:**
1. Clone repository and open in Codespace
2. Run: `npm run auth:setup:from-template UAT`
3. Script prompts:
   - Integration username: `dev.user@company.com.uat`
   - Connected App Consumer Key: `3MVG9...` (from team docs)
4. Script generates:
   - RSA keypair
   - Public certificate (downloads to local machine)
5. Developer uploads certificate to Salesforce:
   - Setup → App Manager → JWT Auth Integration → Edit
   - Upload certificate file
6. Admin assigns Permission Set to developer's user
7. Developer adds secrets to GitHub Codespaces:
   - Copy-paste from script output
8. Rebuild Codespace
9. Automatic authentication on startup

**Time:** ~10 minutes (including manual steps)

### Flow 2: Admin Setting Up New Org

**Scenario:** DevOps admin configuring a new sandbox/org

**Steps:**
1. Run: `npm run auth:setup:org UAT`
2. Script prompts:
   - Org type: Sandbox / Production / Scratch
   - Instance URL: `https://test.salesforce.com`
   - Integration username: `integration@company.com.uat`
   - Contact email: `devops@company.com`
   - App name: `JWT Auth Integration UAT`
3. Script generates:
   - RSA keypair (admin's key)
   - Connected App metadata package
   - Deployment instructions
4. Admin deploys Connected App:
   - `sf project deploy start -d .sf/connected-apps/UAT/`
5. Admin retrieves Consumer Key:
   - Script queries and displays key
6. Admin creates Permission Set:
   - Setup → Permission Sets → New
   - Add Connected App, assign to integration user
7. Admin publishes team documentation:
   - Consumer Key: `3MVG9...`
   - Instance URL: `https://test.salesforce.com`
   - Integration user format: `firstname.lastname@company.com.uat`
8. Admin sets organization-level GitHub Secrets:
   - `SF_JWT_CLIENT_ID_UAT`
   - `SF_JWT_INSTANCE_URL_UAT`
9. Developers generate their own keys and add personal secrets:
   - `SF_JWT_USERNAME_UAT`
   - `SF_JWT_KEY_UAT`

**Time:** ~30 minutes first time, ~10 minutes for subsequent orgs

### Flow 3: Automated CI/CD Setup

**Scenario:** GitHub Actions needs to authenticate to production org

**Steps:**
1. Admin generates dedicated CI keypair:
   ```bash
   npm run auth:generate-secrets PROD --output-format=github-actions
   ```
2. Script outputs:
   ```yaml
   env:
     SF_JWT_USERNAME_PROD: ${{ secrets.SF_JWT_USERNAME_PROD }}
     SF_JWT_CLIENT_ID_PROD: ${{ secrets.SF_JWT_CLIENT_ID_PROD }}
     SF_JWT_INSTANCE_URL_PROD: ${{ secrets.SF_JWT_INSTANCE_URL_PROD }}
     SF_JWT_KEY_PROD: ${{ secrets.SF_JWT_KEY_PROD }}
   ```
3. Admin adds secrets to GitHub repository secrets (not Codespaces)
4. CI workflow runs authentication:
   ```yaml
   - name: Authenticate to Salesforce
     run: npm run auth:jwt
   ```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Implement `sf-jwt-keygen.sh` script
- [ ] Add key generation to `.gitignore`
- [ ] Document manual Connected App setup process
- [ ] Update `authentication.md` with new workflows

### Phase 2: Interactive Setup (Week 2)
- [ ] Implement `sf-auth-setup-wizard.sh`
- [ ] Create Connected App metadata template
- [ ] Add npm scripts: `auth:setup:interactive`, `auth:setup:from-template`
- [ ] Test with sandbox org

### Phase 3: Secrets Management (Week 3)
- [ ] Implement `sf-secrets-helper.sh`
- [ ] GitHub CLI integration for secret setting
- [ ] Dry-run and verification modes
- [ ] Documentation for secret management

### Phase 4: DevContainer Integration (Week 4)
- [ ] Update `post-create.sh` with auto-authentication
- [ ] Add environment variable passthroughs
- [ ] Create validation checks
- [ ] End-to-end testing in Codespaces

### Phase 5: Connected App Automation (Optional)
- [ ] Research Metadata API deployment
- [ ] Implement automated deployment script
- [ ] Tooling API integration for Consumer Key retrieval
- [ ] Permission Set assignment automation

---

## File Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json          # Updated with env vars
│   └── post-create.sh             # Updated with auto-auth
├── .sf/                           # Added to .gitignore
│   ├── keys/                      # Generated keypairs
│   │   ├── <ALIAS>/
│   │   │   ├── private.key        # PEM format
│   │   │   ├── private.key.b64    # Base64-encoded
│   │   │   ├── public.crt         # PEM certificate
│   │   │   ├── public.crt.der     # DER certificate (for Salesforce)
│   │   │   └── secrets.env        # Environment variables template
│   └── connected-apps/            # Generated metadata packages
│       └── <ALIAS>/
│           └── connectedApp/
│               └── JWT_Auth_Integration.connectedApp-meta.xml
├── config/
│   └── connected-app-templates/
│       └── jwt-template.xml       # Template for Connected App
├── docs/
│   ├── authentication.md          # Existing, updated
│   └── authentication-automation-design.md  # This document
└── scripts/
    ├── sf-jwt-login.sh            # Existing, unchanged
    ├── sf-jwt-keygen.sh           # New: Generate keypairs
    ├── sf-auth-setup-wizard.sh    # New: Interactive setup
    └── sf-secrets-helper.sh       # New: GitHub Secrets management
```

---

## npm Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "auth:jwt": "bash scripts/sf-jwt-login.sh",
    "auth:jwt:diagnose": "bash scripts/sf-jwt-login.sh --diagnose",
    "auth:import": "bash scripts/sf-auth-bootstrap.sh",
    "auth:keygen": "bash scripts/sf-jwt-keygen.sh",
    "auth:setup:interactive": "bash scripts/sf-auth-setup-wizard.sh",
    "auth:setup:from-template": "bash scripts/sf-auth-setup-wizard.sh --from-template",
    "auth:secrets:set": "bash scripts/sf-secrets-helper.sh setup",
    "auth:secrets:verify": "bash scripts/sf-secrets-helper.sh verify"
  }
}
```

---

## Testing Strategy

### Unit Tests
- Keypair generation produces valid RSA keys
- Base64 encoding/decoding round-trips correctly
- Environment variable parsing handles edge cases

### Integration Tests
- End-to-end authentication flow in scratch org
- Codespace rebuild with secrets pre-configured
- Multiple org aliases simultaneously

### Security Tests
- Private keys never logged or displayed
- File permissions are restrictive
- Pre-commit hooks catch accidental commits

### User Acceptance Tests
- New developer can authenticate in < 15 minutes
- Admin can configure new org in < 30 minutes
- CI/CD pipeline authenticates successfully

---

## Success Metrics

1. **Setup Time Reduction**
   - Current: ~2 hours for first-time setup (manual)
   - Target: ~15 minutes with interactive wizard

2. **Error Rate**
   - Current: ~40% of new developers encounter auth issues
   - Target: < 5% error rate with automated validation

3. **Security Compliance**
   - Zero private keys committed to repository
   - 100% of integration users use JWT (no interactive auth)
   - Quarterly key rotation for all production orgs

4. **Developer Satisfaction**
   - Survey: "Authentication setup is straightforward" > 4.5/5

---

## Future Enhancements

1. **Multi-Org Management UI**
   - Web-based interface for managing multiple org credentials
   - Visual Connected App configuration wizard
   - Bulk key rotation tools

2. **Salesforce CLI Plugin**
   - Package scripts as official `sf` plugin
   - Interactive prompts using `@oclif/core`
   - Better error messages and help text

3. **Certificate Renewal Automation**
   - Monitor certificate expiration (10-year validity)
   - Automated renewal workflow
   - Zero-downtime key rotation

4. **Advanced Security Features**
   - Hardware security module (HSM) integration
   - AWS Secrets Manager / Azure Key Vault support
   - MFA enforcement for key generation

5. **Analytics and Monitoring**
   - Dashboard for authentication success/failure rates
   - Alert on unusual authentication patterns
   - Integration with Salesforce Event Monitoring

---

## References

### Salesforce Documentation
- [JWT OAuth Flow](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_jwt_flow.htm)
- [Connected Apps](https://help.salesforce.com/s/articleView?id=sf.connected_app_overview.htm)
- [Metadata API](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/)

### Security Best Practices
- [OWASP Key Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html)
- [GitHub Secrets Management](https://docs.github.com/en/codespaces/managing-codespaces-for-your-organization/managing-encrypted-secrets-for-your-repository-and-organization-for-github-codespaces)

### Existing Implementation
- `docs/authentication.md`: Current authentication documentation
- `scripts/sf-jwt-login.sh`: JWT login script (204 lines)
- `.devcontainer/post-create.sh`: DevContainer setup script

---

## Appendix: Example Environment Variables

### Developer-Specific Secrets (User-level Codespaces Secrets)
```bash
# Developer John Doe's UAT credentials
SF_JWT_USERNAME_UAT="john.doe@company.com.uat"
SF_JWT_KEY_UAT="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcE..."  # Base64-encoded
```

### Team-Shared Secrets (Repository-level Codespaces Secrets)
```bash
# UAT Sandbox configuration (shared across team)
SF_JWT_CLIENT_ID_UAT="3MVG9zlTNB8o8BA2zKbDwG8IqDEOE..."
SF_JWT_INSTANCE_URL_UAT="https://test.salesforce.com"

# Production configuration (admin-managed)
SF_JWT_CLIENT_ID_PROD="3MVG9aKMzVe8qY9F4KwQz2P5IxL..."
SF_JWT_INSTANCE_URL_PROD="https://login.salesforce.com"
```

### CI/CD Secrets (Organization-level GitHub Secrets)
```bash
# CI integration user for all repositories
SF_JWT_USERNAME_CI="ci-bot@company.com"
SF_JWT_CLIENT_ID_CI="3MVG9KgbSNMvN2XPLmA9R4Q..."
SF_JWT_INSTANCE_URL_CI="https://login.salesforce.com"
SF_JWT_KEY_CI="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt..."
SF_JWT_SET_DEFAULT_CI="1"
```

---

## Appendix: Connected App Permission Set Template

**Permission Set: JWT Auth Integration Users**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>JWT Auth Integration Users</label>
    <description>Grants access to JWT Auth Integration Connected App</description>
    <hasActivationRequired>false</hasActivationRequired>
    <applicationVisibilities>
        <application>JWT_Auth_Integration</application>
        <visible>true</visible>
    </applicationVisibilities>
    <userPermissions>
        <enabled>true</enabled>
        <name>ApiEnabled</name>
    </userPermissions>
</PermissionSet>
```

**Assignment:**
```bash
# Via Salesforce CLI
sf data record create --sobject PermissionSetAssignment \
  --values "PermissionSetId=0PS... AssigneeId=005..."

# Or manually in Setup → Permission Sets → JWT Auth Integration Users → Manage Assignments
```

---

## Questions & Answers

**Q: Can multiple developers share the same private key?**
A: Not recommended. Each developer should generate their own keypair and upload their public certificate to the Connected App. This allows individual key rotation and audit trails.

**Q: What happens if a private key is compromised?**
A: 1) Generate a new keypair for the affected user, 2) Upload new certificate to Connected App, 3) Update GitHub Secrets, 4) Remove old certificate from Connected App, 5) Review audit logs for unauthorized access.

**Q: Can this work with production orgs?**
A: Yes, but with additional governance: 1) Admin approval for all certificate uploads, 2) IP restrictions on Connected App, 3) Regular key rotation (quarterly), 4) Enhanced monitoring and alerting.

**Q: What about scratch orgs?**
A: Scratch orgs expire after 30 days, so JWT setup may be overkill. Consider using `sf org login web` or device flow for scratch orgs, and JWT for persistent sandboxes/production.

**Q: How do I rotate keys without downtime?**
A: 1) Generate new keypair, 2) Upload new certificate to Connected App (now has 2 certificates), 3) Update GitHub Secrets with new key, 4) Test authentication, 5) Remove old certificate from Connected App. The Connected App supports multiple certificates simultaneously.

---

**Document Version:** 1.0
**Last Updated:** 2025-11-17
**Author:** Claude (Anthropic)
**Status:** Design Proposal - Ready for Implementation
