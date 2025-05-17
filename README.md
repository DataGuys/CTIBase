# Microsoft Defender for Endpoint Indicator Management

This solution provides a comprehensive system for managing Microsoft Defender for Endpoint (MDE) indicators through a custom Log Analytics workspace and table. It automatically synchronizes indicators between MDE and Azure Sentinel, providing a centralized management interface.

## Overview

The solution includes:

- Custom Log Analytics table for storing MDE indicators
- Logic App to synchronize indicators from MDE every 6 hours
- Workbook for visualization and management of indicators
- Playbook to sync changes back to MDE
- Key Vault integration for secure credential storage

## Prerequisites

Before deploying this solution, you must create an application registration with the necessary permissions to access MDE APIs. Use the provided script to create this registration.

```bash
# Copy and run this in a bash environment (Azure Cloud Shell or WSL)
curl -sL https://raw.githubusercontent.com/DataGuys/CTIBase/refs/heads/main/scripts/create-mde-app-registration.sh | tr -d '\r' | bash
```

## Deployment

Click the button below to deploy this solution to your Azure environment:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDataGuys%2FCTIBase%2Frefs%2Fheads%2Fmain%2Fazuredeploy.json)

### Deployment Parameters

| Parameter | Description |
|-----------|-------------|
| `workspaceName` | Name for the Log Analytics workspace |
| `location` | Azure region for deployment |
| `appId` | Application (client) ID from the app registration |
| `keyVaultName` | Name for the Key Vault to store secrets |
| `logicAppName` | Name for the Logic App that syncs MDE indicators |
| `playbookName` | Name for the Playbook that syncs updates back to MDE |

## Post-Deployment Configuration

After deployment:

1. Assign the Managed Identity permissions to the Key Vault
2. Verify the Logic App is running on schedule
3. Access the Workbook to view and manage indicators

## Solution Components

### Custom Log Analytics Table

The solution creates a custom table in Log Analytics with the schema necessary to hold all MDE indicator properties.

### Logic App

The Logic App connects to the MDE API endpoint (`https://api.securitycenter.microsoft.com/api/indicators`) every 6 hours to retrieve a copy of all current indicators and store them in the custom table.

### Workbook

The included workbook provides visualization of all indicator types and allows for management (adding/removing) of indicators directly from the interface.

### Playbook

The playbook synchronizes any updates from the custom table back to MDE, ensuring they stay in sync. Indicators added directly to MDE are imported and flagged in the workbook.

## Troubleshooting

If you encounter issues:

1. Verify that the app registration has all required permissions
2. Check that the Managed Identity has been granted access to the Key Vault
3. Inspect the Logic App runs for any error messages

## Contributing

Contributions to improve this solution are welcome. Please submit issues or pull requests to the [GitHub repository](https://github.com/DataGuys/CTIBase).
