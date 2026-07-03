# Connected App Automation MVP - Quick Start

## TL;DR

Automate Connected App creation using Salesforce APIs. Requires one-time web login to bootstrap.

```bash
# 1. Bootstrap authentication (one-time)
sf org login web --alias uat

# 2. Generate keypair
npm run auth:keygen UAT

# 3. Install dependencies
npm install

# 4. Create Connected App automatically
npm run connected-app:create UAT admin@example.com uat

# 5. Complete 2 manual steps (shown in output)
#    - Upload certificate
#    - Assign Connected App to Permission Set

# 6. Test authentication
npm run auth:jwt
```

**Time savings:** ~45 minutes per org (55 min → 8 min)

---

## The Problem This Solves

**Without MVP:** Creating a Connected App for JWT authentication requires ~15 manual steps across multiple Salesforce Setup pages, taking 45-60 minutes per org.

**With MVP:** Automate 80% of the process via APIs, reducing setup to ~8 minutes per org.

---

## The Bootstrap Chicken-and-Egg Problem

**Q:** How do you use APIs to create a Connected App when you need the Connected App to authenticate to the APIs?

**A:** Use existing Salesforce CLI authentication (web login) to bootstrap the process.

```
┌──────────────────────────────────────────────────────┐
│  Bootstrap Flow                                       │
│                                                       │
│  1. Admin logs in via web browser (one-time)         │
│         ↓                                             │
│  2. Salesforce CLI stores access token               │
│         ↓                                             │
│  3. Automation uses that token to call APIs          │
│         ↓                                             │
│  4. APIs create the Connected App                    │
│         ↓                                             │
│  5. Future authentication uses the Connected App     │
│                                                       │
└──────────────────────────────────────────────────────┘
```

This is a **one-time manual step**. Once the Connected App exists, all future authentication uses JWT (fully automated).

---

## What Gets Automated

✅ **Fully Automated (via API):**
- Connected App creation
- Consumer Key retrieval
- Permission Set creation
- Permission Set → User assignment
- OAuth policy configuration (attempted)

⚠️ **Manual Steps Required (API Limitations):**
- Certificate upload (~2 min)
- Connected App → Permission Set assignment (~1 min)

**Why manual?** Salesforce doesn't expose certificate or Connected App assignment fields in Tooling/Metadata APIs.

---

## Prerequisites

1. **Authenticated to Salesforce org:**
   ```bash
   sf org login web --alias <org-alias>
   ```

2. **Node.js installed** (v20+)

3. **Dependencies installed:**
   ```bash
   npm install
   ```

---

## Usage

### Basic Usage

```bash
npm run connected-app:create <ALIAS> <EMAIL> [ORG_ALIAS]
```

**Arguments:**
- `ALIAS`: Org identifier (e.g., UAT, PROD, DEV)
- `EMAIL`: Contact email for the Connected App
- `ORG_ALIAS`: (Optional) Salesforce org alias from `sf org list`

### Example 1: UAT Sandbox

```bash
# Authenticate
sf org login web --alias uat-sandbox

# Generate keypair
npm run auth:keygen UAT

# Create Connected App
npm run connected-app:create UAT admin@example.com uat-sandbox
```

**Output:**
```
[INFO] Creating Connected App: JWT Auth Integration UAT
[SUCCESS] Connected App deployed successfully
[SUCCESS] Retrieved Consumer Key: 3MVG9zlTNB...
[SUCCESS] Permission Set created: JWT Auth UAT Users
[WARN] Certificate upload via API is not directly supported.
       Please upload manually: .sf/keys/UAT/public.crt.der

╔════════════════════════════════════════════════════╗
║                 Setup Summary                      ║
╚════════════════════════════════════════════════════╝

Consumer Key: 3MVG9zlTNB8o8BA2zKbDwG8IqDE...

Manual Steps Required:
  1. Upload certificate to Connected App
     Setup → App Manager → JWT Auth Integration UAT → Edit
     Enable "Use digital signatures"
     Upload: .sf/keys/UAT/public.crt.der

  2. Assign Connected App to Permission Set
     Setup → Permission Sets → JWT Auth UAT Users
     Assigned Connected Apps → Add → JWT Auth Integration UAT

Environment Variables:
  export SF_JWT_CLIENT_ID_UAT="3MVG9zlTNB..."
  export SF_JWT_USERNAME_UAT="<your-username>"
  export SF_JWT_INSTANCE_URL_UAT="https://test.salesforce.com"
```

### Example 2: Production Org with Integration User

```bash
# Authenticate
sf org login web --alias prod

# Setup (generates keypair + secrets template)
npm run auth:setup:interactive
# → Select alias: PROD
# → Enter username: integration@company.com
# → (Creates .sf/keys/PROD/ with all files)

# Create Connected App (auto-detects username from secrets.env)
npm run connected-app:create PROD admin@example.com prod

# Script will automatically:
# ✅ Create Connected App
# ✅ Create Permission Set
# ✅ Assign Permission Set to integration@company.com

# You complete manually:
# ⚠️ Upload certificate
# ⚠️ Assign Connected App to Permission Set

# Test
npm run auth:jwt:diagnose
npm run auth:jwt
```

### Example 3: Multiple Orgs (Batch Processing)

```bash
# Authenticate to all orgs first
sf org login web --alias uat
sf org login web --alias staging
sf org login web --alias prod

# Generate keypairs
for alias in UAT STAGING PROD; do
  npm run auth:keygen $alias
done

# Create Connected Apps
npm run connected-app:create UAT admin@example.com uat
npm run connected-app:create STAGING admin@example.com staging
npm run connected-app:create PROD admin@example.com prod

# Complete manual steps for each (certificate upload + assignment)

# Result: 3 orgs set up in ~25 minutes vs. ~3 hours manually
```

---

## Manual Steps (Detailed Instructions)

After running the automation, complete these two steps:

### Step 1: Upload Certificate (~2 minutes)

1. Go to **Setup** → **App Manager**
2. Find your Connected App (e.g., "JWT Auth Integration UAT")
3. Click the dropdown → **Edit**
4. Scroll to **API (Enable OAuth Settings)**
5. Check **Use digital signatures**
6. Click **Choose File**
7. Select: `.sf/keys/<ALIAS>/public.crt.der`
8. Click **Save**

**Verification:**
- You should see the certificate details (Subject, Issuer, Expiry)
- Certificate is valid for 10 years

### Step 2: Assign Connected App to Permission Set (~1 minute)

1. Go to **Setup** → **Permission Sets**
2. Find: "JWT Auth \<ALIAS\> Users"
3. Click the Permission Set name
4. Click **Assigned Connected Apps**
5. Click **Add**
6. Select your Connected App (e.g., "JWT Auth Integration UAT")
7. Click **Save**

**Verification:**
- The Connected App should appear in "Assigned Connected Apps"
- No errors displayed

---

## Testing Authentication

After completing manual steps:

```bash
# Validate configuration
npm run auth:jwt:diagnose

# Expected output:
# [OK]   UAT: RSA private key detected
# [OK]   UAT: username/clientId/instance present

# Authenticate
ONLY_ALIAS=UAT npm run auth:jwt

# Expected output:
# Using JWT script: /path/to/scripts/sf-jwt-login.sh
# JWT login for alias: UAT (user: integration@company.com.uat, host: https://test.salesforce.com)
# Logged in: UAT
# JWT logins complete.

# Verify
sf org display -o UAT
```

---

## CI/CD Integration

Use in GitHub Actions:

```yaml
name: Setup Connected App

on:
  workflow_dispatch:
    inputs:
      org_alias:
        required: true
      contact_email:
        required: true

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm install

      - name: Install Salesforce CLI
        run: npm install -g @salesforce/cli

      - name: Authenticate
        run: |
          echo "${{ secrets.SFDX_AUTH_URL }}" | \
            sf org login sfdx-url --alias bootstrap --sfdx-url-stdin

      - name: Generate keypair
        run: npm run auth:keygen ${{ inputs.org_alias }}

      - name: Create Connected App
        run: |
          npm run connected-app:create \
            ${{ inputs.org_alias }} \
            ${{ inputs.contact_email }} \
            bootstrap

      - name: Save Consumer Key
        id: app-info
        run: |
          # Parse Consumer Key from output
          # Set as GitHub secret for future workflows

      - name: Notify admin for manual steps
        run: |
          echo "Connected App created!"
          echo "Admin: please upload certificate and assign to Permission Set"
          echo "Certificate: .sf/keys/${{ inputs.org_alias }}/public.crt.der"
```

---

## Troubleshooting

### "Not authenticated to org"

```bash
# Check authenticated orgs
sf org list

# Re-authenticate
sf org login web --alias <org-alias>
```

### "Connected App already exists"

The script is idempotent. If the app exists, it will:
- Skip creation
- Retrieve existing Consumer Key
- Update other resources

Safe to re-run.

### "Dependencies not found"

```bash
npm install
```

### "Permission denied"

```bash
chmod +x scripts/sf-connected-app-create.sh
```

### Certificate upload fails

**Symptom:** "Invalid certificate" error

**Solutions:**
- Verify you're uploading the **.der** file (not .crt or .key)
- Location: `.sf/keys/<ALIAS>/public.crt.der`
- The .crt.der file is specifically formatted for Salesforce

### Authentication fails after setup

**Checklist:**
1. ✅ Certificate uploaded to Connected App?
2. ✅ OAuth Policies set to "Admin approved users are pre-authorized"?
3. ✅ Connected App assigned to Permission Set?
4. ✅ Permission Set assigned to user?
5. ✅ User has "API Enabled" permission?

Run diagnose:
```bash
npm run auth:jwt:diagnose
```

---

## API Limitations (Why Some Steps Are Manual)

### Certificate Upload
- **API:** ConnectedApplication (Tooling API)
- **Issue:** Certificate fields are not exposed
- **Workaround:** Manual upload or browser automation (Selenium)

### Connected App → Permission Set Assignment
- **API:** PermissionSet (Metadata API)
- **Issue:** `assignedConnectedApps` field is for tab visibility, not OAuth access
- **Workaround:** Manual assignment or Metadata API with full replacement

### Possible Future Solutions
1. **Salesforce Enhancement:** Add certificate upload to API
2. **Browser Automation:** Use Selenium/Playwright for UI interactions
3. **Unlocked Package:** Pre-configure and distribute

---

## Cost-Benefit Analysis

### Time Investment

**First Org:**
- Setup automation: 0 min (already done)
- Bootstrap auth: 2 min
- Run script: 2 min
- Manual steps: 4 min
- **Total: 8 min** (vs. 55 min manual)

**Additional Orgs:**
- Run script: 2 min
- Manual steps: 4 min
- **Total: 6 min** (vs. 55 min manual)

### ROI

| Orgs | Manual Time | MVP Time | Time Saved |
|------|-------------|----------|------------|
| 1    | 55 min      | 8 min    | 47 min     |
| 3    | 165 min     | 20 min   | 145 min    |
| 5    | 275 min     | 32 min   | 243 min    |
| 10   | 550 min     | 62 min   | 488 min    |

**Recommendation:** Use MVP for 2+ orgs. Breaks even immediately.

---

## Next Steps

1. **Try it:**
   ```bash
   npm run connected-app:create TEST test@example.com
   ```

2. **Read the full documentation:**
   - `docs/connected-app-automation-mvp.md` - Complete technical details
   - `docs/authentication-automation-design.md` - Overall design

3. **Provide feedback:**
   - Did it work?
   - How long did it take?
   - What could be better?

---

## FAQ

**Q: Is this safe for production?**
A: Yes, with proper review. The script uses official Salesforce APIs. Review the generated Connected App settings before using in production.

**Q: Can I customize the Connected App name?**
A: Yes, edit the Node.js script or use direct invocation:
```bash
node scripts/lib/connected-app-automation.js \
  --alias PROD \
  --email admin@example.com \
  --label "My Custom App Name"
```

**Q: Does this work with My Domain?**
A: Yes, the script auto-detects your org's instance URL.

**Q: Can I use this for scratch orgs?**
A: Technically yes, but scratch orgs expire after 30 days. JWT setup may be overkill. Consider `sf org login web` for scratch orgs.

**Q: What permissions does the automation user need?**
A: "Modify All Data" OR "Customize Application" to create Connected Apps via API.

**Q: Can I run this multiple times?**
A: Yes, the script is idempotent. It checks for existing apps and skips creation if found.

---

**Happy automating! 🚀**
