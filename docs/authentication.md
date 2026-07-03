# Authentication in Codespaces (Standardized)

This guide shows fast, repeatable ways to authenticate to many Salesforce orgs (sandboxes, dev, prod) from GitHub Codespaces without interactive browser flows.

Recommended options:

- **JWT with Automated Setup** (recommended - fully automated, secure, repeatable)
- SFDX Auth URL (quick, human-friendly)
- JWT Manual Setup (for advanced users)

Device flow is deprecated (removal mid-January 2026); avoid for new setups.

## Quick Start: Automated JWT Setup (Recommended)

For first-time setup or adding a new org, use the interactive wizard:

```bash
npm run auth:setup:interactive
```

This wizard will:
1. Generate RSA keypairs automatically
2. Guide you through Connected App creation
3. Create environment variable templates
4. Help you add secrets to GitHub Codespaces

**For full documentation on automated setup, see:** `docs/authentication-automation-design.md`

## Automated Connected App Creation (MVP - For Admins)

For admins managing multiple orgs, you can automate Connected App creation via APIs:

```bash
# 1. Bootstrap authentication (one-time)
sf org login web --alias uat

# 2. Generate keypair and create Connected App via API
npm run auth:keygen UAT
npm install  # Install jsforce, xmlbuilder2, archiver
npm run connected-app:create UAT admin@example.com uat

# 3. Complete 2 manual steps (certificate upload, app assignment)
#    Total time: ~8 minutes vs. 55 minutes manual
```

This MVP:
- ✅ Creates Connected App via Metadata API
- ✅ Retrieves Consumer Key via Tooling API
- ✅ Creates and assigns Permission Set
- ⚠️ Requires manual certificate upload (API limitation)
- ⚠️ Requires manual Connected App → Permission Set assignment

**Quick Start Guide:** `docs/CONNECTED_APP_MVP_QUICKSTART.md`
**Technical Details:** `docs/connected-app-automation-mvp.md`

## Option A: SFDX Auth URL (fastest to reuse)

An SFDX Auth URL contains a refresh token for a logged-in user. Generate once on a trusted machine, then inject into Codespaces as environment variables.

Steps to generate locally:

1. Login to your org (web/device) and set an alias, e.g. `mySandbox`.
2. Export the auth URL:
    - sf: `sf org display --json -o mySandbox | jq -r '.result.sfdxAuthUrl'`
    - sfdx: `sfdx force:org:display -u mySandbox --verbose --json | jq -r '.result.sfdxAuthUrl'`
3. Store the URL securely (never commit). Use Codespaces Secrets or your vault.

Use in Codespaces:

1. Define environment variables (in Codespaces secrets or repo → Codespaces → Secrets):
    - `SFDX_AUTH_URL_UAT=https://...`
    - `SFDX_AUTH_URL_DEV=https://...`
2. Import them into the CLI keychain:
    - `bash scripts/sf-auth-bootstrap.sh`
3. Verify:
    - `sf org list` (or `sfdx force:org:list`)

Notes:

- Rotate if the user resets password/MFA/token.
- Add one env var per org you need.

## Option B: JWT (server-to-server; ideal for CI/integration)

JWT removes interactive auth and avoids device flow deprecation.

One-time org setup:

1. Connected App
    - Enable OAuth and select scopes: `api`, `refresh_token, offline_access` (+ `openid`/`id` optional)
    - Enable "Use digital signatures" and upload the public X.509 certificate
    - OAuth Policies: set "Admin approved users are pre-authorized"
2. Permission Set
    - Add the Connected App under "Enabled Connected Apps"
    - Assign the Permission Set to your integration user (with API enabled)
3. Keys
    - Generate an RSA keypair (keep private key secret). Upload only the cert to the Connected App

Provide credentials to Codespaces via environment variables (recommended):

- `SF_JWT_USERNAME_<ALIAS>`: integration user username (e.g. `user@example.com.sandbox`)
- `SF_JWT_CLIENT_ID_<ALIAS>`: Connected App Consumer Key
- `SF_JWT_INSTANCE_URL_<ALIAS>`: `https://login.salesforce.com` | `https://test.salesforce.com` | `https://<my-domain>.my.salesforce.com`
- `SF_JWT_KEY_<ALIAS>`: private key, base64-encoded (preferred) or raw
- Optional: `SF_JWT_KEY_IS_B64_<ALIAS>=0` if your private key env value is NOT base64
- Optional: `SF_JWT_SET_DEFAULT_<ALIAS>=1` to set as default after login

Login all defined aliases in one command:

```
bash scripts/sf-jwt-login.sh
```

Limit to one alias:

```
ONLY_ALIAS=UAT bash scripts/sf-jwt-login.sh
```

Verify:

- `sf org list` and `sf org display -o <alias>`

### Diagnose mode (validate env and key without login)

Use diagnose to verify variables/key formatting and app access before attempting auth:

```
npm run auth:jwt:diagnose
```

What it does:

- Checks presence of `SF_JWT_USERNAME_<ALIAS>`, `SF_JWT_CLIENT_ID_<ALIAS>`, `SF_JWT_INSTANCE_URL_<ALIAS>`, and `SF_JWT_KEY_<ALIAS>`
- Validates the key header (must be RSA PRIVATE KEY) and PEM formatting
- Prints instance URL and flags (b64/default) per alias
- Does not attempt login or persist the key

Tips:

- Prefer a dedicated integration user; ensure org policies allow API/JWT.
- Use your My Domain instance URL if SSO/MFA routing is required.

## Choosing between methods

- Use SFDX Auth URLs when you already have interactive access and want a quick, reusable setup per sandbox.
- Use JWT for long-lived, non-interactive access (CI/CD, automation, headless Codespaces). JWT is the recommended long-term approach.

## Security notes

- Never commit tokens or private keys.
- Prefer GitHub Codespaces Secrets for per-user secrets and organization-level Codespaces secrets for shared CI users.
- Rotate credentials periodically and when users leave projects.

## Automating Codespaces Secrets

Options to streamline secret provisioning:

- Organization-level Codespaces Secrets: define shared secrets once at the org level (scoped to selected repos). Best for shared CI/integration users.
- Repository-level Codespaces Secrets: define per-repo; you can script creation with GitHub CLI (`gh secret set --app codespaces`) from a secure admin environment.
- Environment variables file: for local testing only, you can export secrets in the terminal; do not commit. For repeatable setups, prefer GitHub Secrets.

Note: Creating Codespaces secrets programmatically typically requires running `gh` with sufficient repo/org permissions. Avoid embedding secrets in repo files or logs.

## Available npm Scripts

### Authentication Setup
- `npm run auth:setup:interactive` - Interactive wizard for full JWT setup (recommended)
- `npm run auth:setup:from-template` - Setup with existing Connected App
- `npm run auth:keygen <ALIAS>` - Generate RSA keypair only

### Authentication
- `npm run auth:jwt` - Authenticate all configured aliases
- `npm run auth:jwt:diagnose` - Validate configuration without authenticating
- `npm run auth:import` - Import SFDX Auth URLs

### Secrets Management
- `npm run auth:secrets:setup <ALIAS>` - Add secrets to GitHub Codespaces
- `npm run auth:secrets:verify [ALIAS]` - Verify secrets are configured correctly
- `npm run auth:secrets:list` - List all configured aliases
- `npm run auth:secrets:export <ALIAS>` - Export secrets as shell commands

## Troubleshooting

- RS256 requires an RSA private key in PEM format. If you see "secretOrPrivateKey must be an asymmetric key when using RS256", you likely provided the wrong key type (e.g., EC key), the public certificate instead of the private key, or the key lost newlines. Prefer base64-encoding the private key and set `SF_JWT_KEY_IS_B64_<ALIAS>=1`.
- For detailed troubleshooting, see `config/connected-app-templates/README.md`
