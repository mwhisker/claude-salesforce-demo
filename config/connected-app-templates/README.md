# Connected App Templates

This directory contains templates for creating Connected Apps for Salesforce JWT authentication.

## Manual Setup (Recommended)

The most secure and reliable way to set up a Connected App is through the Salesforce UI:

1. **Navigate to Setup → App Manager**
2. **Click "New Connected App"**
3. **Configure basic information:**
   - Connected App Name: `JWT Auth Integration <ALIAS>`
   - API Name: `JWT_Auth_Integration_<ALIAS>`
   - Contact Email: your-email@example.com

4. **Enable OAuth Settings:**
   - ✅ Enable OAuth Settings
   - Callback URL: `https://login.salesforce.com/services/oauth2/success`
   - ✅ Use digital signatures
   - Upload certificate: `.sf/keys/<ALIAS>/public.crt.der`
   - Select OAuth Scopes:
     - Access and manage your data (api)
     - Perform requests on your behalf at any time (refresh_token, offline_access)

5. **Save and configure policies:**
   - After saving, click "Manage" → "Edit Policies"
   - Permitted Users: **Admin approved users are pre-authorized**
   - IP Relaxation: **Relax IP restrictions** (for development) or **Enforce IP restrictions** (for production)

6. **Create Permission Set:**
   - Setup → Permission Sets → New
   - Label: `JWT Auth <ALIAS> Users`
   - Go to: Assigned Connected Apps → Add
   - Select your Connected App
   - Assign the Permission Set to your integration user

## Automated Setup (Advanced)

For organizations that need to provision Connected Apps programmatically, you can use the Metadata API.

### Option A: Using Salesforce DX

**Requirements:**
- Admin access to the target org
- Consumer Key must be generated after deployment
- Certificate must be uploaded separately (cannot be embedded in metadata)

**Limitations:**
- The Metadata API **cannot** set the Consumer Key (it's auto-generated)
- The Metadata API **cannot** upload certificates directly
- OAuth policies may need manual configuration

Due to these limitations, **manual setup is strongly recommended** for initial Connected App creation.

### Option B: Using Tooling API (Future Enhancement)

The Tooling API provides more control over Connected App configuration:

```javascript
// Example: Query Connected App Consumer Key
const query = "SELECT Id, ConsumerKey FROM ConnectedApplication WHERE Name='JWT Auth Integration UAT'";
const result = await conn.tooling.query(query);
console.log(result.records[0].ConsumerKey);
```

**Note:** This requires custom scripting and is not yet implemented in this project.

## Template Files

- **connectedApp/JWT_Auth_Integration.connectedApp-meta.xml** - Metadata template (reference only)

This template is provided for reference purposes. Due to Metadata API limitations with certificates and Consumer Keys, **manual setup through the Salesforce UI is the recommended approach**.

## Quick Start

To set up JWT authentication:

1. **Generate keypair:**
   ```bash
   npm run auth:keygen <ALIAS>
   ```

2. **Run interactive setup:**
   ```bash
   npm run auth:setup:interactive
   ```

3. **Follow the wizard** - it will guide you through:
   - Generating RSA keypairs
   - Creating the Connected App (manual steps)
   - Configuring OAuth policies
   - Setting up Permission Sets
   - Adding secrets to GitHub Codespaces

## Security Best Practices

1. **Use separate Connected Apps per environment** (DEV, UAT, PROD)
2. **Never share private keys** - each developer should generate their own
3. **Rotate certificates** quarterly for production environments
4. **Use "Admin approved users are pre-authorized"** - never allow self-authorization
5. **Assign Permission Sets** carefully - only to users who need API access
6. **Monitor usage** via Setup → Identity → Event Log Files

## Troubleshooting

### "Invalid JWT Signature" Error

**Causes:**
- Wrong private key (doesn't match uploaded certificate)
- Certificate not uploaded or not saved
- Private key has formatting issues (newlines, encoding)

**Solutions:**
- Verify certificate is uploaded in Connected App settings
- Regenerate keypair and re-upload certificate
- Ensure private key is base64-encoded: `SF_JWT_KEY_IS_B64_<ALIAS>=1`

### "User is not admin approved to access this app" Error

**Causes:**
- OAuth policy is not set to "Admin approved users are pre-authorized"
- Permission Set not assigned to integration user
- Permission Set doesn't include the Connected App

**Solutions:**
- Edit Connected App → OAuth Policies → Permitted Users
- Verify Permission Set assignment
- Ensure Permission Set has "Assigned Connected Apps" configured

### "Client identifier invalid" Error

**Causes:**
- Wrong Consumer Key in `SF_JWT_CLIENT_ID_<ALIAS>`
- Connected App is inactive or deleted

**Solutions:**
- Verify Consumer Key: Setup → App Manager → <App> → View
- Check Connected App is active

## References

- [Salesforce JWT OAuth Flow](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_jwt_flow.htm)
- [Connected Apps](https://help.salesforce.com/s/articleView?id=sf.connected_app_overview.htm)
- [Metadata API Limitations](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_connectedapp.htm)
