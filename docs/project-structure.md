# Project Structure

This document provides an overview of the project's file structure and the purpose of each component.

## Root Directory

- **README.md**: Main documentation file with project overview and deployment instructions
- **LICENSE**: MIT License file
- **.gitignore**: Git ignore file to exclude credentials and other sensitive files
- **azuredeploy.json**: ARM template for deploying the entire solution

## Directories

### `/scripts`

Contains shell scripts for setup and configuration:

- **create-mde-app-registration.sh**: Script to create the app registration with required permissions
- **add-secret-to-keyvault.sh**: Helper script to add the client secret to Key Vault

### `/schemas`

Contains schema definitions and examples:

- **indicator-schema.json**: Example schema showing MDE indicator structure

### `/docs`

Documentation for various aspects of the solution:

- **installation-guide.md**: Step-by-step guide for installing and configuring the solution
- **workbook-guide.md**: Guide for using the MDE Indicator Management Workbook

## Deployment Components

The ARM template (azuredeploy.json) deploys the following resources:

1. **Log Analytics Workspace**: Stores the MDE indicators
   - Custom table: `MDEIndicators_CL`

2. **Key Vault**: Securely stores the app registration client secret

3. **Managed Identity**: Used by Logic Apps to access Key Vault

4. **Logic App (MDE-Indicator-Sync)**: 
   - Runs every 6 hours
   - Fetches indicators from MDE API
   - Stores them in Log Analytics

5. **Logic App (MDE-Indicator-Update-Sync)**:
   - Triggered when indicators are modified in Log Analytics
   - Syncs changes back to MDE

6. **Workbook**: Interactive dashboard for indicator management
