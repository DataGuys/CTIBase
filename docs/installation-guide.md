# Installation and Configuration Guide

This guide provides step-by-step instructions for deploying and configuring the MDE Indicator Sync solution.

## Prerequisites

- Azure subscription with owner or contributor permissions
- Microsoft Defender for Endpoint licensed and configured
- Permissions to create app registrations in Microsoft Entra ID (formerly Azure AD)
- Azure CLI installed (for app registration script)

## Step 1: Create the App Registration

The app registration is required to grant the Logic App permissions to access the Microsoft Defender for Endpoint API.

1. Download or copy the `create-mde-app-registration.sh` script from this repository

2. Run the script using Bash in Azure Cloud Shell, WSL, or Git Bash:
   ```bash
   bash create-mde-app-registration.sh
   ```

3. Follow the script prompts - it will:
   - Create a new app registration
   - Add the required API permissions
   - Generate a client secret
   - Save credentials to `mde-app-credentials.env`

4. After the script completes, grant admin consent for the API permissions:
   - Navigate to Microsoft Entra ID > App registrations
   - Select the app: `MDE-Indicator-Sync-App`
   - Go to API permissions
   - Click "Grant admin consent for <your-tenant>"

5. Make note of the Application (Client) ID from the script output or the `mde-app-credentials.env` file. You'll need this for the deployment.

## Step 2: Deploy the ARM Template

1. Click the "Deploy to Azure" button in the repository README.md

2. Fill in the deployment parameters:
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: Create new or use existing
   - **Region**: Select the Azure region for deployment
   - **Workspace Name**: Name for the Log Analytics workspace
   - **App ID**: Paste the Application (Client) ID from Step 1
   - **Key Vault Name**: Provide a globally unique name for the Key Vault
   - **Logic App Name**: Name for the Logic App (default is fine)
   - **Playbook Name**: Name for the Playbook (default is fine)
   - **Workbook Name**: Name for the workbook (default is fine)

3. Click "Review + create" and then "Create" to deploy the solution

## Step 3: Post-Deployment Configuration

1. Add the client secret to your Key Vault:
   ```bash
   az keyvault secret set --vault-name YOUR_KEYVAULT_NAME --name MDEAppSecret --value YOUR_CLIENT_SECRET
   ```
   Replace YOUR_KEYVAULT_NAME with the Key Vault name you provided during deployment, and YOUR_CLIENT_SECRET with the secret from the `mde-app-credentials.env` file.

2. Verify Logic App Connections:
   - Navigate to the deployed Logic App in the Azure Portal
   - Click on the Logic App and check the "Connections" tab
   - Ensure the Key Vault and Log Analytics connections are authorized
   - If needed, click "Edit" on a connection and authorize access

3. Run the Logic App:
   - Navigate to the deployed Logic App
   - Click "Run Trigger" > "Recurrence" to manually trigger the first run
   - Check the run history to ensure it completed successfully

4. Open the Workbook:
   - Navigate to the Azure Portal > Microsoft Sentinel
   - Select your workspace
   - Go to "Workbooks" and find "MDE Indicator Management"
   - Click to open the workbook

## Step 4: Verify the Deployment

1. Check the Log Analytics custom table:
   - Navigate to the Log Analytics workspace
   - Go to "Logs" and run a simple query: `MDEIndicators_CL`
   - Verify that indicators are being synchronized

2. Test indicator management:
   - Use the workbook to add a test indicator
   - Verify it appears in both the workbook and in MDE

## Troubleshooting

If you encounter issues:

- **Logic App run failures**:
  - Check the run history for error details
  - Verify the Key Vault contains the correct client secret
  - Ensure all API permissions have admin consent

- **No indicators in Log Analytics**:
  - Check the MDE environment to verify indicators exist
  - Verify the app registration has correct permissions
  - Check the Logic App run history for errors

- **Workbook doesn't show indicators**:
  - Verify the custom table name is correct (`MDEIndicators_CL`)
  - Check that indicators exist in the Log Analytics workspace

For additional help, please open an issue in the GitHub repository.
