#!/usr/bin/env node

/**
 * Automated Connected App Creation for Salesforce JWT Authentication
 *
 * This script demonstrates how to programmatically create and configure
 * a Connected App using Salesforce Metadata and Tooling APIs.
 *
 * Bootstrap Problem:
 * - To create a Connected App via API, you need authentication
 * - The Connected App is what we want to use for authentication
 *
 * Solution (this MVP):
 * - Use existing Salesforce CLI authentication (web login, SFDX auth URL)
 * - Create the Connected App programmatically
 * - Retrieve the auto-generated Consumer Key
 * - Configure OAuth policies
 * - Create and assign Permission Set
 *
 * Prerequisites:
 * - Authenticated to Salesforce org: sf org login web --alias <org>
 * - npm install jsforce xmlbuilder2
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Color output helpers
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
};

function error(msg) {
    console.error(`${colors.red}[ERROR]${colors.reset} ${msg}`);
}

function success(msg) {
    console.log(`${colors.green}[SUCCESS]${colors.reset} ${msg}`);
}

function info(msg) {
    console.log(`${colors.blue}[INFO]${colors.reset} ${msg}`);
}

function warn(msg) {
    console.log(`${colors.yellow}[WARN]${colors.reset} ${msg}`);
}

/**
 * Get Salesforce connection using existing CLI authentication
 */
async function getConnection(orgAlias) {
    info(`Getting connection for org: ${orgAlias || 'default'}`);

    try {
        // Get org info from Salesforce CLI
        const cmd = orgAlias
            ? `sf org display --json -o ${orgAlias}`
            : `sf org display --json`;

        const result = JSON.parse(execSync(cmd, { encoding: 'utf-8' }));

        if (result.status !== 0) {
            throw new Error(`Failed to get org info: ${result.message}`);
        }

        const orgInfo = result.result;

        info(`Connected to: ${orgInfo.instanceUrl}`);
        info(`Username: ${orgInfo.username}`);
        info(`Org ID: ${orgInfo.id}`);

        // Use jsforce with the access token
        const jsforce = require('jsforce');
        const conn = new jsforce.Connection({
            instanceUrl: orgInfo.instanceUrl,
            accessToken: orgInfo.accessToken,
            version: '63.0'
        });

        return { conn, orgInfo };
    } catch (err) {
        error(`Failed to connect to Salesforce: ${err.message}`);
        error('Make sure you are authenticated: sf org login web --alias <org>');
        throw err;
    }
}

/**
 * Check if Connected App already exists
 */
async function checkConnectedAppExists(conn, appName) {
    info(`Checking if Connected App '${appName}' exists...`);

    try {
        const query = `SELECT Id, Name, ConsumerKey FROM ConnectedApplication WHERE Name = '${appName}' LIMIT 1`;
        const result = await conn.tooling.query(query);

        if (result.records.length > 0) {
            return result.records[0];
        }

        return null;
    } catch (err) {
        warn(`Error checking for existing app: ${err.message}`);
        return null;
    }
}

/**
 * Create Connected App metadata XML
 */
function createConnectedAppMetadata(config) {
    const { create } = require('xmlbuilder2');

    const xml = create({ version: '1.0', encoding: 'UTF-8' })
        .ele('ConnectedApp', { xmlns: 'http://soap.sforce.com/2006/04/metadata' })
            .ele('label').txt(config.label).up()
            .ele('description').txt(config.description || 'JWT Authentication Connected App').up()
            .ele('contactEmail').txt(config.contactEmail).up()
            .ele('oauthConfig')
                .ele('callbackUrl').txt('https://login.salesforce.com/services/oauth2/success').up()
                .ele('scopes').txt('Api').up()
                .ele('scopes').txt('RefreshToken').up()
                .ele('scopes').txt('OfflineAccess').up()
                .ele('isAdminApproved').txt('false').up()
                .ele('isConsumerSecret').txt('false').up()
            .up()
        .up();

    return xml.end({ prettyPrint: true });
}

/**
 * Deploy Connected App using Metadata API
 */
async function deployConnectedApp(conn, config) {
    info(`Creating Connected App: ${config.label}`);

    try {
        // Create metadata directory structure
        const tempDir = path.join(process.cwd(), '.sf', 'temp-metadata', config.apiName);
        const metadataDir = path.join(tempDir, 'connectedApps');

        fs.mkdirSync(metadataDir, { recursive: true });

        // Create package.xml
        const packageXml = `<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>${config.apiName}</members>
        <name>ConnectedApp</name>
    </types>
    <version>63.0</version>
</Package>`;

        fs.writeFileSync(path.join(tempDir, 'package.xml'), packageXml);

        // Create Connected App metadata
        const appMetadata = createConnectedAppMetadata(config);
        fs.writeFileSync(
            path.join(metadataDir, `${config.apiName}.connectedApp`),
            appMetadata
        );

        info(`Deploying metadata from: ${tempDir}`);

        // Deploy using Metadata API
        return new Promise((resolve, reject) => {
            const zipStream = require('archiver')('zip');
            const chunks = [];

            zipStream.on('data', (chunk) => chunks.push(chunk));
            zipStream.on('end', async () => {
                const zipBuffer = Buffer.concat(chunks);

                try {
                    const result = await conn.metadata.deploy(zipBuffer, {
                        singlePackage: true,
                        rollbackOnError: true
                    }).complete(true);

                    // Clean up temp directory
                    fs.rmSync(tempDir, { recursive: true, force: true });

                    if (result.success) {
                        success('Connected App deployed successfully');
                        resolve(result);
                    } else {
                        error('Deployment failed:');
                        console.error(JSON.stringify(result, null, 2));
                        reject(new Error('Deployment failed'));
                    }
                } catch (err) {
                    error(`Deployment error: ${err.message}`);
                    reject(err);
                }
            });

            zipStream.on('error', reject);

            // Add files to zip
            zipStream.append(packageXml, { name: 'package.xml' });
            zipStream.append(appMetadata, { name: `connectedApps/${config.apiName}.connectedApp` });
            zipStream.finalize();
        });
    } catch (err) {
        error(`Failed to deploy Connected App: ${err.message}`);
        throw err;
    }
}

/**
 * Retrieve Consumer Key using Tooling API
 */
async function getConsumerKey(conn, appName) {
    info('Retrieving Consumer Key...');

    // Wait a bit for the app to be available
    await new Promise(resolve => setTimeout(resolve, 5000));

    try {
        const query = `SELECT Id, Name, ConsumerKey FROM ConnectedApplication WHERE Name = '${appName}' LIMIT 1`;
        const result = await conn.tooling.query(query);

        if (result.records.length === 0) {
            throw new Error('Connected App not found after deployment');
        }

        const app = result.records[0];
        success(`Retrieved Consumer Key: ${app.ConsumerKey.substring(0, 10)}...${app.ConsumerKey.slice(-4)}`);

        return {
            id: app.Id,
            name: app.Name,
            consumerKey: app.ConsumerKey
        };
    } catch (err) {
        error(`Failed to retrieve Consumer Key: ${err.message}`);
        throw err;
    }
}

/**
 * Upload certificate to Connected App
 * Note: This is one of the limitations - certificates must be uploaded via UI
 */
async function uploadCertificate(conn, appId, certificatePath) {
    warn('Certificate upload via API is not directly supported.');
    warn('Certificates must be uploaded manually via Salesforce UI:');
    console.log(`  1. Setup → App Manager → [Find your app]`);
    console.log(`  2. Click "Edit"`);
    console.log(`  3. Enable "Use digital signatures"`);
    console.log(`  4. Upload certificate: ${certificatePath}`);
    console.log('');

    // Note: There's no direct API to upload certificates
    // The ConnectedApplication object in Tooling API doesn't expose certificate fields
    // This must be done through the UI

    return false;
}

/**
 * Update OAuth policies using Metadata API
 */
async function updateOAuthPolicies(conn, config) {
    info('Updating OAuth policies...');

    try {
        const metadata = [{
            fullName: config.apiName,
            oauthConfig: {
                isAdminApproved: true, // This is the key setting we need
                ipRelaxation: 'RELAX_IP_RESTRICTIONS' // For development
            }
        }];

        const result = await conn.metadata.update('ConnectedApp', metadata);

        if (result[0].success) {
            success('OAuth policies updated');
            return true;
        } else {
            warn('Failed to update OAuth policies via API');
            warn('Please update manually:');
            console.log('  Setup → App Manager → [Your App] → Manage');
            console.log('  Edit Policies → Permitted Users: Admin approved users are pre-authorized');
            return false;
        }
    } catch (err) {
        warn(`Could not update OAuth policies: ${err.message}`);
        warn('Manual configuration may be required');
        return false;
    }
}

/**
 * Create Permission Set
 */
async function createPermissionSet(conn, config) {
    info(`Creating Permission Set: ${config.permSetLabel}`);

    try {
        // Check if Permission Set exists
        const existingPS = await conn.query(
            `SELECT Id FROM PermissionSet WHERE Name = '${config.permSetName}' LIMIT 1`
        );

        if (existingPS.records.length > 0) {
            warn('Permission Set already exists');
            return existingPS.records[0].Id;
        }

        // Create Permission Set via Metadata API
        const metadata = [{
            fullName: config.permSetName,
            label: config.permSetLabel,
            description: `Access to ${config.label} Connected App`,
            hasActivationRequired: false
        }];

        const result = await conn.metadata.create('PermissionSet', metadata);

        if (result[0].success) {
            success(`Permission Set created: ${config.permSetLabel}`);

            // Retrieve the ID
            const ps = await conn.query(
                `SELECT Id FROM PermissionSet WHERE Name = '${config.permSetName}' LIMIT 1`
            );
            return ps.records[0].Id;
        } else {
            throw new Error(result[0].errors.join(', '));
        }
    } catch (err) {
        error(`Failed to create Permission Set: ${err.message}`);
        throw err;
    }
}

/**
 * Assign Connected App to Permission Set
 */
async function assignConnectedAppToPermissionSet(conn, permSetId, appId) {
    warn('Connected App assignment to Permission Set via API is limited.');
    warn('Please assign manually:');
    console.log('  1. Setup → Permission Sets → [Your Permission Set]');
    console.log('  2. Assigned Connected Apps → Add');
    console.log('  3. Select your Connected App');
    console.log('');

    // Note: PermissionSetAssignment is for users, not Connected Apps
    // ConnectedAppPermission is not directly writable via API

    return false;
}

/**
 * Assign Permission Set to User
 */
async function assignPermissionSetToUser(conn, permSetId, username) {
    info(`Assigning Permission Set to user: ${username}`);

    try {
        // Get user ID
        const userResult = await conn.query(
            `SELECT Id FROM User WHERE Username = '${username}' LIMIT 1`
        );

        if (userResult.records.length === 0) {
            throw new Error(`User not found: ${username}`);
        }

        const userId = userResult.records[0].Id;

        // Check if already assigned
        const existingAssignment = await conn.query(
            `SELECT Id FROM PermissionSetAssignment
             WHERE PermissionSetId = '${permSetId}'
             AND AssigneeId = '${userId}'
             LIMIT 1`
        );

        if (existingAssignment.records.length > 0) {
            warn('Permission Set already assigned to user');
            return true;
        }

        // Create assignment
        const assignment = await conn.sobject('PermissionSetAssignment').create({
            PermissionSetId: permSetId,
            AssigneeId: userId
        });

        if (assignment.success) {
            success('Permission Set assigned to user');
            return true;
        } else {
            throw new Error(assignment.errors.join(', '));
        }
    } catch (err) {
        error(`Failed to assign Permission Set: ${err.message}`);
        throw err;
    }
}

/**
 * Main orchestration function
 */
async function createJWTConnectedApp(options) {
    console.log('\n╔════════════════════════════════════════════════════════════════════════╗');
    console.log('║         Automated Connected App Creation (MVP)                        ║');
    console.log('╚════════════════════════════════════════════════════════════════════════╝\n');

    const config = {
        label: options.label || `JWT Auth Integration ${options.alias}`,
        apiName: options.apiName || `JWT_Auth_Integration_${options.alias}`,
        description: options.description || 'JWT Authentication Connected App (auto-generated)',
        contactEmail: options.contactEmail,
        alias: options.alias,
        permSetName: options.permSetName || `JWT_Auth_${options.alias}_Users`,
        permSetLabel: options.permSetLabel || `JWT Auth ${options.alias} Users`,
        certificatePath: options.certificatePath,
        username: options.username
    };

    try {
        // Step 1: Get connection using existing CLI auth
        const { conn, orgInfo } = await getConnection(options.orgAlias);

        // Step 2: Check if app already exists
        const existingApp = await checkConnectedAppExists(conn, config.label);

        let appInfo;
        if (existingApp) {
            warn(`Connected App '${config.label}' already exists`);
            appInfo = {
                id: existingApp.Id,
                name: existingApp.Name,
                consumerKey: existingApp.ConsumerKey
            };
            success(`Consumer Key: ${appInfo.consumerKey.substring(0, 10)}...${appInfo.consumerKey.slice(-4)}`);
        } else {
            // Step 3: Deploy Connected App
            await deployConnectedApp(conn, config);

            // Step 4: Retrieve Consumer Key
            appInfo = await getConsumerKey(conn, config.label);

            // Step 5: Update OAuth policies
            await updateOAuthPolicies(conn, config);
        }

        // Step 6: Upload certificate (manual step required)
        if (config.certificatePath) {
            await uploadCertificate(conn, appInfo.id, config.certificatePath);
        }

        // Step 7: Create Permission Set
        const permSetId = await createPermissionSet(conn, config);

        // Step 8: Assign Connected App to Permission Set (manual step)
        await assignConnectedAppToPermissionSet(conn, permSetId, appInfo.id);

        // Step 9: Assign Permission Set to user
        if (config.username) {
            await assignPermissionSetToUser(conn, permSetId, config.username);
        }

        // Summary
        console.log('\n╔════════════════════════════════════════════════════════════════════════╗');
        console.log('║                          Setup Summary                                 ║');
        console.log('╚════════════════════════════════════════════════════════════════════════╝\n');

        success('Automated setup completed!');
        console.log('');
        console.log('Connected App Details:');
        console.log(`  Name: ${appInfo.name}`);
        console.log(`  Consumer Key: ${appInfo.consumerKey}`);
        console.log('');
        console.log('Manual Steps Required:');
        console.log('  1. Upload certificate to Connected App (see above)');
        console.log('  2. Assign Connected App to Permission Set (see above)');
        console.log('  3. Verify OAuth policies: Setup → App Manager → [App] → Manage');
        console.log('');
        console.log('Environment Variables:');
        console.log(`  export SF_JWT_CLIENT_ID_${config.alias}="${appInfo.consumerKey}"`);
        console.log(`  export SF_JWT_USERNAME_${config.alias}="${config.username || '<your-username>'}"`);
        console.log(`  export SF_JWT_INSTANCE_URL_${config.alias}="${orgInfo.instanceUrl.replace('//', '//')}"`);
        console.log('');

        return appInfo;

    } catch (err) {
        error(`\nSetup failed: ${err.message}`);
        process.exit(1);
    }
}

// CLI interface
if (require.main === module) {
    const args = process.argv.slice(2);

    if (args.length === 0 || args.includes('--help')) {
        console.log(`
Automated Connected App Creation for JWT Authentication

Usage:
  node scripts/lib/connected-app-automation.js --alias <ALIAS> --email <EMAIL> [options]

Required:
  --alias <ALIAS>              Org alias (e.g., UAT, PROD)
  --email <EMAIL>              Contact email for Connected App

Optional:
  --org <ORG>                  Salesforce org alias (default: uses default org)
  --username <USERNAME>        Integration user to assign Permission Set to
  --cert <PATH>                Path to certificate file (.crt.der)
  --label <LABEL>              Custom Connected App label
  --description <DESC>         Custom description

Examples:
  # Basic usage
  node scripts/lib/connected-app-automation.js --alias UAT --email admin@example.com

  # With org alias and certificate
  node scripts/lib/connected-app-automation.js \\
    --alias PROD \\
    --email admin@example.com \\
    --org my-prod-org \\
    --cert .sf/keys/PROD/public.crt.der \\
    --username integration@company.com

Prerequisites:
  1. Authenticate to Salesforce: sf org login web --alias <org>
  2. Install dependencies: npm install
`);
        process.exit(0);
    }

    // Parse arguments
    const options = {};
    for (let i = 0; i < args.length; i += 2) {
        const key = args[i].replace(/^--/, '');
        const value = args[i + 1];
        options[key] = value;
    }

    if (!options.alias || !options.email) {
        error('Missing required arguments: --alias and --email');
        error('Run with --help for usage information');
        process.exit(1);
    }

    options.contactEmail = options.email;
    options.orgAlias = options.org;
    options.certificatePath = options.cert;

    createJWTConnectedApp(options).catch(err => {
        error(`Fatal error: ${err.message}`);
        process.exit(1);
    });
}

module.exports = { createJWTConnectedApp, getConnection };
