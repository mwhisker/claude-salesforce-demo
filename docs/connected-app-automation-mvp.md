# Connected App Automation MVP

## The Bootstrap Problem

To create a Connected App programmatically, we face a classic "chicken and egg" problem:

```
┌─────────────────────────────────────────────────────────────┐
│  THE BOOTSTRAP PROBLEM                                       │
│                                                              │
│  ┌──────────────────────────┐                               │
│  │                          │                               │
│  │   To use APIs, we need   │                               │
│  │   authentication         │                               │
│  │                          │                               │
│  └────────────┬─────────────┘                               │
│               │                                              │
│               ▼                                              │
│  ┌──────────────────────────┐                               │
│  │                          │                               │
│  │   To authenticate via    │                               │
│  │   JWT, we need a         │                               │
│  │   Connected App          │                               │
│  │                          │                               │
│  └────────────┬─────────────┘                               │
│               │                                              │
│               ▼                                              │
│  ┌──────────────────────────┐                               │
│  │                          │                               │
│  │   To create a Connected  │                               │
│  │   App, we need API       │                               │
│  │   authentication         │                               │
│  │                          │                               │
│  └──────────────────────────┘                               │
│                                                              │
│  ❌ Infinite loop!                                           │
└─────────────────────────────────────────────────────────────┘
```

## Solution Approaches

### Approach 1: Manual Bootstrap (Current Implementation)
Use existing authentication to create the first Connected App.

```bash
# Step 1: Authenticate via web browser (one-time)
sf org login web --alias bootstrap-org

# Step 2: Use this authentication to create Connected App
npm run connected-app:create UAT admin@example.com bootstrap-org

# Step 3: Now use the Connected App for JWT authentication
npm run auth:jwt
```

**Pros:**
- Simple and reliable
- Uses official Salesforce CLI
- No deprecated authentication methods
- Admin controls the process

**Cons:**
- Requires one-time manual web login
- Admin intervention needed

### Approach 2: Username/Password Flow (Deprecated)
Use username/password OAuth flow for initial bootstrap.

```javascript
// ⚠️ DEPRECATED - Not recommended for new implementations
conn.login(username, password + securityToken);
```

**Pros:**
- Can be fully automated

**Cons:**
- ❌ Deprecated by Salesforce
- ❌ Requires security token
- ❌ Less secure (password in script)
- ❌ May be disabled in many orgs

### Approach 3: Existing SFDX Auth URL (Recommended for CI/CD)
Use an SFDX Auth URL from a previously authenticated session.

```bash
# Admin generates auth URL once
sf org display --json -o prod | jq -r '.result.sfdxAuthUrl'

# Store in CI/CD secrets as BOOTSTRAP_AUTH_URL

# CI/CD uses it to authenticate
echo "$BOOTSTRAP_AUTH_URL" | sf org login sfdx-url --alias bootstrap --sfdx-url-stdin

# Now create Connected App
npm run connected-app:create PROD admin@example.com bootstrap
```

**Pros:**
- No passwords in scripts
- Works in CI/CD
- Refresh token can be long-lived

**Cons:**
- Admin must generate and share auth URL securely
- Auth URL contains refresh token (treat as password)

### Approach 4: Pre-existing Connected App (This MVP)
Use an existing Connected App to create additional Connected Apps.

**Scenario:** You already have one Connected App for admin tasks.

```bash
# Use existing admin Connected App to create team Connected Apps
npm run connected-app:create UAT_TEAM admin@example.com admin-org
npm run connected-app:create DEV_TEAM admin@example.com admin-org
```

**Pros:**
- Scalable for multiple orgs
- Separation of concerns (admin vs. team apps)

**Cons:**
- Still needs initial bootstrap

## MVP Implementation

This MVP demonstrates **Approach 1: Manual Bootstrap** as the most practical solution.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  BOOTSTRAP PHASE (One-time)                                 │
│                                                              │
│  Admin → Web Login → Salesforce CLI → Access Token          │
│                                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  AUTOMATION PHASE                                            │
│                                                              │
│  Access Token                                                │
│       │                                                      │
│       ├─→ Metadata API → Deploy Connected App               │
│       │                                                      │
│       ├─→ Tooling API → Retrieve Consumer Key               │
│       │                                                      │
│       ├─→ Metadata API → Create Permission Set              │
│       │                                                      │
│       └─→ SOAP API → Assign Permission Set to User          │
│                                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  OUTPUT                                                      │
│                                                              │
│  ✅ Connected App Created                                    │
│  ✅ Consumer Key Retrieved                                   │
│  ✅ Permission Set Created                                   │
│  ✅ User Assigned                                            │
│  ⚠️  Certificate Upload (manual - API limitation)           │
│  ⚠️  OAuth Policies (may need manual verification)          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### What This MVP Automates

✅ **Fully Automated:**
1. Connected App creation via Metadata API
2. Consumer Key retrieval via Tooling API
3. Permission Set creation via Metadata API
4. Permission Set assignment to user via SOAP API

⚠️ **Partially Automated:**
1. OAuth policy configuration (attempted via API, may need verification)

❌ **Manual Steps Required (API Limitations):**
1. **Certificate Upload**: Salesforce doesn't expose certificate fields in Tooling/Metadata APIs
2. **Connected App → Permission Set Assignment**: No direct API to assign Connected Apps to Permission Sets

### API Limitations Discovered

#### 1. Certificate Upload
**Problem:** The `ConnectedApplication` object in both Tooling and Metadata APIs doesn't expose certificate data fields.

**Attempted Solutions:**
- Metadata API `ConnectedApp` type: No certificate field
- Tooling API `ConnectedApplication` object: Fields are read-only
- REST API: No endpoint for certificate upload

**Current Solution:** Manual upload through UI after creation.

**Future Possibility:**
- Salesforce may add this capability in future API versions
- Could potentially use browser automation (Selenium/Playwright) as a workaround

#### 2. Connected App → Permission Set Assignment
**Problem:** The relationship between Connected Apps and Permission Sets isn't directly writeable via API.

**Metadata API:** The `PermissionSet` metadata type has an `applicationVisibilities` field, but it's for **tab visibility**, not Connected App access.

**Attempted Field:** `assignedConnectedApps` - doesn't exist in API

**Current Solution:** Manual assignment through UI.

### Usage Examples

#### Example 1: Basic Setup

```bash
# Step 1: Authenticate to Salesforce (bootstrap)
sf org login web --alias uat-sandbox

# Step 2: Generate keypair
npm run auth:keygen UAT

# Step 3: Create Connected App
npm run connected-app:create UAT admin@example.com uat-sandbox

# Step 4: Follow manual steps displayed
# - Upload certificate: .sf/keys/UAT/public.crt.der
# - Assign Connected App to Permission Set

# Step 5: Test JWT authentication
npm run auth:jwt:diagnose
npm run auth:jwt
```

#### Example 2: With Integration User

```bash
# Create secrets file first
npm run auth:setup:interactive

# This creates:
# - Keypair
# - .sf/keys/UAT/secrets.env with username

# Now create Connected App (will auto-detect username)
npm run connected-app:create UAT admin@example.com uat-sandbox

# Permission Set is automatically assigned to the integration user
```

#### Example 3: CI/CD Pipeline

```yaml
# .github/workflows/setup-connected-app.yml
name: Setup Connected App

on:
  workflow_dispatch:
    inputs:
      org_alias:
        description: 'Org alias (e.g., UAT, PROD)'
        required: true
      contact_email:
        description: 'Contact email'
        required: true

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm install

      - name: Install Salesforce CLI
        run: npm install -g @salesforce/cli

      - name: Authenticate to Salesforce
        run: |
          echo "${{ secrets.SFDX_AUTH_URL }}" | \
            sf org login sfdx-url --alias bootstrap --sfdx-url-stdin

      - name: Generate keypair
        run: npm run auth:keygen ${{ github.event.inputs.org_alias }}

      - name: Create Connected App
        run: |
          npm run connected-app:create \
            ${{ github.event.inputs.org_alias }} \
            ${{ github.event.inputs.contact_email }} \
            bootstrap

      - name: Save artifacts
        uses: actions/upload-artifact@v3
        with:
          name: connected-app-config
          path: .sf/keys/${{ github.event.inputs.org_alias }}/
```

### Implementation Details

#### Technologies Used

- **Node.js**: Runtime for automation script
- **jsforce**: Salesforce API library
- **xmlbuilder2**: Generate Metadata API XML
- **archiver**: Create deployment ZIP packages

#### APIs Used

1. **Metadata API** (`conn.metadata.*`)
   - `deploy()`: Deploy Connected App
   - `create()`: Create Permission Set
   - `update()`: Update OAuth policies

2. **Tooling API** (`conn.tooling.query()`)
   - Query `ConnectedApplication` for Consumer Key
   - Query app details after creation

3. **SOAP API** (`conn.sobject()`)
   - Create `PermissionSetAssignment`
   - Query users and Permission Sets

4. **Salesforce CLI** (via `execSync`)
   - Retrieve access token and org info
   - Leverage existing authentication

#### Code Structure

```
scripts/
├── lib/
│   └── connected-app-automation.js    # Main automation logic
└── sf-connected-app-create.sh         # Shell wrapper

Flow:
1. getConnection() - Use Salesforce CLI auth
2. checkConnectedAppExists() - Check for existing app
3. deployConnectedApp() - Deploy via Metadata API
4. getConsumerKey() - Query via Tooling API
5. updateOAuthPolicies() - Configure via Metadata API
6. createPermissionSet() - Create via Metadata API
7. assignPermissionSetToUser() - Assign via SOAP API
```

### Testing the MVP

#### Test 1: Basic Creation

```bash
# Setup
sf org login web --alias test-org
npm run auth:keygen TEST

# Execute
npm run connected-app:create TEST test@example.com test-org

# Verify
sf org display -o test-org
# Should see Connected App in Setup → App Manager
```

#### Test 2: Idempotency

```bash
# Run twice - should detect existing app
npm run connected-app:create TEST test@example.com test-org
npm run connected-app:create TEST test@example.com test-org

# Expected: Second run skips creation, retrieves existing Consumer Key
```

#### Test 3: Permission Set Assignment

```bash
# Create with specific user
node scripts/lib/connected-app-automation.js \
  --alias TEST \
  --email test@example.com \
  --org test-org \
  --username integration@company.com.test

# Verify in Salesforce
sf data query --query "SELECT AssigneeId, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.Name LIKE 'JWT_Auth_TEST%'" -o test-org
```

## Comparison: Manual vs. MVP

### Manual Setup (Before MVP)

1. ⏱️ **15 minutes**: Generate keypair manually
2. ⏱️ **10 minutes**: Create Connected App in UI
3. ⏱️ **5 minutes**: Upload certificate
4. ⏱️ **5 minutes**: Configure OAuth policies
5. ⏱️ **10 minutes**: Create Permission Set
6. ⏱️ **5 minutes**: Assign Connected App to Permission Set
7. ⏱️ **5 minutes**: Assign Permission Set to user

**Total: ~55 minutes per org**

### MVP Setup (With This Script)

1. ⏱️ **2 minutes**: One-time: `sf org login web`
2. ⏱️ **1 minute**: Generate keypair: `npm run auth:keygen`
3. ⏱️ **2 minutes**: Run automation: `npm run connected-app:create`
4. ⏱️ **3 minutes**: Manual: Upload certificate + assign Connected App

**Total: ~8 minutes per org (86% reduction)**

### Multiple Orgs

**Manual:** 55 min × 5 orgs = **4.6 hours**
**MVP:** 8 min × 5 orgs = **40 minutes**

## Limitations and Future Enhancements

### Current Limitations

1. **Certificate Upload**: Must be done manually (API limitation)
2. **Connected App → Permission Set**: Must be done manually (API limitation)
3. **Bootstrap Required**: Still needs initial web login
4. **Single Org at a Time**: No batch processing yet

### Future Enhancements

#### Phase 1: UI Automation (Selenium)
Use browser automation to handle manual steps:

```javascript
// Pseudo-code
const { Builder } = require('selenium-webdriver');

async function uploadCertificate(accessToken, appId, certPath) {
    const driver = await new Builder().forBrowser('chrome').build();

    // Navigate to Connected App edit page
    await driver.get(`https://mydomain.my.salesforce.com/setup/ui/edit/${appId}`);

    // Inject access token for session
    await driver.executeScript(`localStorage.setItem('token', '${accessToken}')`);

    // Upload certificate via file input
    const fileInput = await driver.findElement(By.id('certFileInput'));
    await fileInput.sendKeys(certPath);

    // Save
    await driver.findElement(By.id('saveButton')).click();
}
```

**Pros:**
- Fully automates manual steps
- Uses official UI (no API hacks)

**Cons:**
- Brittle (UI changes break automation)
- Requires headless browser
- Slower than API calls

#### Phase 2: Package-Based Deployment
Create an unlocked package with pre-configured Connected App.

```bash
# Create package
sf package create --name "JWT Auth Kit" --package-type Unlocked

# Add Connected App metadata
# (Still requires certificate upload post-deployment)

# Install in target org
sf package install --package "JWT Auth Kit@1.0.0"
```

**Pros:**
- Distributable to multiple orgs
- Versioned configuration
- Salesforce-native approach

**Cons:**
- Still requires certificate upload
- Package development overhead
- Less flexible than script

#### Phase 3: Managed Package
Publish as a managed package on AppExchange.

**Pros:**
- Professional distribution
- ISV-level automation
- Namespace protection

**Cons:**
- Cannot modify in subscriber orgs
- AppExchange submission process
- Licensing considerations

#### Phase 4: OAuth Device Flow Bootstrap
Use OAuth device flow for initial authentication in CI/CD.

```bash
# CI/CD starts device flow
sf org login device --client-id <universal-device-flow-app-id>

# Displays code: XXXX-YYYY

# Admin approves via browser (could be scripted notification)

# Once approved, automation continues
npm run connected-app:create ...
```

**Pros:**
- No refresh tokens to manage
- More secure than SFDX auth URLs
- Works in restricted environments

**Cons:**
- Device flow deprecated (removal Jan 2026)
- Still requires admin approval

## Security Considerations

### Bootstrap Authentication
- **Access Token**: Short-lived (usually 2 hours)
- **Refresh Token**: Long-lived but should be rotated
- **SFDX Auth URL**: Contains refresh token - treat as password

### Recommendations
1. Use web login for interactive sessions
2. Use SFDX Auth URLs for CI/CD (store in secrets)
3. Rotate refresh tokens quarterly
4. Audit Connected App usage via Event Monitoring

### Principle of Least Privilege
The automation requires:
- **Modify All Data** OR **Customize Application** permission
- Only grant to trusted admins
- Use dedicated admin user for automation

## Conclusion

This MVP demonstrates that **partial automation** of Connected App creation is possible:

✅ **Automated:**
- App creation
- Consumer Key retrieval
- Permission Set management
- User assignment

❌ **Still Manual:**
- Certificate upload
- Connected App → Permission Set assignment
- Initial bootstrap authentication

**Recommendation:**
- Use this MVP for **multi-org deployments** where time savings justify the setup
- For **single-org setups**, the interactive wizard (`npm run auth:setup:interactive`) may be simpler
- For **enterprise deployments**, consider combining this MVP with Selenium for full automation

**ROI:** Saves ~45 minutes per org. Breaks even at 1 org, valuable at 3+ orgs.

## References

- [Salesforce Metadata API: ConnectedApp](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_connectedapp.htm)
- [Tooling API: ConnectedApplication](https://developer.salesforce.com/docs/atlas.en-us.api_tooling.meta/api_tooling/tooling_api_objects_connectedapplication.htm)
- [jsforce Documentation](https://jsforce.github.io/)
- [OAuth 2.0 JWT Bearer Flow](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_jwt_flow.htm)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-17
**Status:** MVP Implementation - Ready for Testing
