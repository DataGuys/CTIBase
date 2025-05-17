#!/bin/bash
# MDE Indicator Sync App Registration Script - Permissions for the Logic Apps to access MDE indicators
set -e

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n======================================================="
echo "     MDE Indicator Sync Application Registration Setup"
echo "======================================================="

echo -e "${BLUE}Checking prerequisites...${NC}"
if ! az account show &> /dev/null; then
  echo -e "${YELLOW}Not logged in to Azure.${NC}"
  az login
fi

# Get subscription and tenant details
SUB_NAME=$(az account show --query name -o tsv)
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${GREEN}Using subscription: ${SUB_NAME} (${SUB_ID})${NC}"
echo -e "${GREEN}Tenant ID: ${TENANT_ID}${NC}"

# Create app registration
APP_NAME="MDE-Indicator-Sync-App"
echo "Creating app registration: ${APP_NAME}..."
APP_CREATE=$(az ad app create --display-name "${APP_NAME}")
APP_ID=$(echo "$APP_CREATE" | jq -r '.appId // .id')
OBJECT_ID=$(echo "$APP_CREATE" | jq -r '.id // .objectId')

if [ -z "$APP_ID" ]; then
  echo -e "${RED}Failed to retrieve Application ID.${NC}"
  exit 1
fi

echo -e "${GREEN}Application successfully created.${NC}"
echo -e "${GREEN}Application (Client) ID: ${APP_ID}${NC}"

echo "Creating service principal for the application..."
az ad sp create --id "$APP_ID" || {
  echo -e "${RED}Failed to create service principal.${NC}"
  exit 1
}
echo -e "${GREEN}Service principal created successfully.${NC}"

# Save credentials to a file
echo "CLIENT_ID=${APP_ID}" > mde-app-credentials.env
echo "APP_OBJECT_ID=${OBJECT_ID}" >> mde-app-credentials.env
echo "APP_NAME=${APP_NAME}" >> mde-app-credentials.env

echo -e "${BLUE}Adding required permissions...${NC}"

# Microsoft Threat Protection API permissions
echo "Adding Microsoft Threat Protection API permissions..."
# resourceAppId: 8ee8fdad-f234-4243-8f3b-15c294843740 (Microsoft Threat Intelligence API)

# ThreatIndicators.ReadWrite - Read and write threat intelligence indicators
az ad app permission add --id "$APP_ID" \
  --api 8ee8fdad-f234-4243-8f3b-15c294843740 \
  --api-permissions "7734e8e5-8dde-42fc-b5ae-6eafea078693=Role"

# Microsoft Graph API permissions
echo "Adding Microsoft Graph permissions..."
# resourceAppId: 00000003-0000-0000-c000-000000000000

# ThreatIndicators.ReadWrite.OwnedBy - Manage threat indicators this app creates or owns
az ad app permission add --id "$APP_ID" \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions "21792b6c-c986-4ffc-85de-df9da54b52fa=Role"

# ThreatIntelligence.ReadWrite - Read and write threat intelligence information
az ad app permission add --id "$APP_ID" \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions "197ee4e9-b993-4066-898f-d6aecc55125b=Role"

# Windows Defender ATP API permissions
echo "Adding Windows Defender ATP permissions..."
# resourceAppId: fc780465-2017-40d4-a0c5-307022471b92
az ad app permission add --id "$APP_ID" \
  --api fc780465-2017-40d4-a0c5-307022471b92 \
  --api-permissions "76767153-6b9f-4456-a270-7a8a8a1e68ea=Role"

# Defender Threat Management API
echo "Adding Microsoft Defender for Endpoint API permissions..."
# resourceAppId: 05a65629-4c1b-48c1-a78b-804c4abdd4af

# Ti.ReadWrite - Read and write Indicators
az ad app permission add --id "$APP_ID" \
  --api 05a65629-4c1b-48c1-a78b-804c4abdd4af \
  --api-permissions "41ba7d20-b411-42ca-9fee-1fbca7b4965f=Role"

echo -e "${GREEN}API permissions added successfully.${NC}"

echo -e "${BLUE}Creating client secret...${NC}"
SECRET_YEARS=2
echo "Creating client secret with ${SECRET_YEARS} year(s) duration..."
SECRET_RESULT=$(az ad app credential reset --id "$APP_ID" --years "$SECRET_YEARS" --query password -o tsv)

if [ -z "$SECRET_RESULT" ]; then
  echo -e "${RED}Failed to create client secret.${NC}"
  exit 1
fi

echo "CLIENT_SECRET=${SECRET_RESULT}" >> mde-app-credentials.env
echo -e "${GREEN}Client secret created successfully and saved to mde-app-credentials.env${NC}"
echo -e "${YELLOW}IMPORTANT: Keep this file secure as it contains your client secret!${NC}"

echo -e "\n======================================================="
echo "               Setup Complete!"
echo "======================================================="

echo "App registration has been created successfully with necessary security permissions."
echo -e "\n${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo "1. Grant admin consent for API permissions in the Azure Portal:"
echo "   - Navigate to: Microsoft Entra ID > App registrations"
echo "   - Select your app: ${APP_NAME}"
echo "   - Go to 'API permissions'"
echo "   - Click 'Grant admin consent for <your-tenant>'"

echo -e "\n2. Add the client secret to your Key Vault:"
echo "   - Run the following commands to add the secret to your Key Vault after deployment:"
echo "   ----------------------------------------"
echo "   az keyvault secret set --vault-name YOUR_KEYVAULT_NAME --name MDEAppSecret --value ${SECRET_RESULT}"
echo "   ----------------------------------------"

echo -e "\n3. Deploy the MDE Indicator Sync solution using the 'Deploy to Azure' button in the README"
echo "   and provide the following Application (Client) ID when prompted:"
echo "   ----------------------------------------"
echo "   ${APP_ID}"
echo "   ----------------------------------------"

echo -e "\nYour app credentials have been saved to: mde-app-credentials.env"
