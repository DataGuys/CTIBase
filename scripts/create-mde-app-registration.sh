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
echo "     Indicator Sync Application Registration Setup"
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

# Prompt for resource group
echo -e "${BLUE}Please enter a resource group name to create or use:${NC}"
read -p "Resource Group Name: " RESOURCE_GROUP
echo -e "${BLUE}Please enter the Azure region (e.g., eastus, westeurope):${NC}"
read -p "Azure Region: " LOCATION

# Check if resource group exists, create if it doesn't
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
  echo "Creating resource group ${RESOURCE_GROUP} in ${LOCATION}..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

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

# Save app ID and other non-sensitive info to a file
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

# Create a Key Vault for storing the secret
echo -e "${BLUE}Creating Key Vault to store client secret...${NC}"
KV_NAME="mde-indicator-kv-$(tr -dc 'a-z0-9' < /dev/urandom | fold -w 8 | head -n 1)"
echo "Creating Key Vault: ${KV_NAME}..."

az keyvault create \
  --name "$KV_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku standard \
  --enabled-for-template-deployment true \
  || {
    echo -e "${RED}Failed to create Key Vault.${NC}"
    exit 1
  }

echo -e "${GREEN}Key Vault created successfully: ${KV_NAME}${NC}"
echo "KEYVAULT_NAME=${KV_NAME}" >> mde-app-credentials.env

# Create client secret
echo -e "${BLUE}Creating client secret and storing in Key Vault...${NC}"
SECRET_YEARS=2
echo "Creating client secret with ${SECRET_YEARS} year(s) duration..."

# Create the secret but don't display it
SECRET_RESULT=$(az ad app credential reset --id "$APP_ID" --years "$SECRET_YEARS" --query password -o tsv)

if [ -z "$SECRET_RESULT" ]; then
  echo -e "${RED}Failed to create client secret.${NC}"
  exit 1
fi

# Store the secret in Key Vault (without displaying it)
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "IndicatorAppSecret" \
  --value "$SECRET_RESULT" \
  --output none

echo -e "${GREEN}Client secret created and securely stored in Key Vault '${KV_NAME}' with name 'IndicatorAppSecret'${NC}"

echo -e "\n======================================================="
echo "               Setup Complete!"
echo "======================================================="

echo "App registration has been created successfully with necessary security permissions."
echo -e "Client secret has been securely stored in Key Vault and can be used for Logic App permissioning."

echo -e "\n${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo "1. Grant admin consent for API permissions in the Azure Portal:"
echo "   - Navigate to: Microsoft Entra ID > App registrations"
echo "   - Select your app: ${APP_NAME}"
echo "   - Go to 'API permissions'"
echo "   - Click 'Grant admin consent for <your-tenant>'"

echo -e "\n2. Deploy the MDE Indicator Sync solution using the following parameters:"
echo "   - Application (Client) ID: ${APP_ID}"
echo "   - Key Vault Name: ${KV_NAME}"
echo "   - Secret Name: IndicatorAppSecret"

echo -e "\nYour app registration and Key Vault details have been saved to: mde-app-credentials.env"
echo -e "${YELLOW}NOTE: Your client secret has been securely stored in Key Vault and is NOT in the credentials file.${NC}"
