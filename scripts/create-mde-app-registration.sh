#!/bin/bash
# Indicator Sync App Registration Script - Permissions for the Logic Apps to access indicators
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

# Handle command-line arguments
RESOURCE_GROUP=""
LOCATION=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -g|--resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -g, --resource-group    Resource group name"
      echo "  -l, --location          Azure region (e.g., eastus, westeurope)"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

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

# Prompt for resource group and location if not provided as arguments
if [ -z "$RESOURCE_GROUP" ]; then
  if [ -t 0 ]; then  # Check if stdin is a terminal
    echo -e "${BLUE}Please enter a resource group name to create or use:${NC}"
    read -p "Resource Group Name: " RESOURCE_GROUP
  else
    # Default resource group name when run non-interactively
    RESOURCE_GROUP="mde-indicator-sync-rg"
    echo "Using default resource group: $RESOURCE_GROUP"
  fi
fi

if [ -z "$LOCATION" ]; then
  if [ -t 0 ]; then  # Check if stdin is a terminal
    echo -e "${BLUE}Please enter the Azure region (e.g., eastus, westeurope):${NC}"
    read -p "Azure Region: " LOCATION
  else
    # Default location when run non-interactively
    LOCATION="eastus"
    echo "Using default location: $LOCATION"
  fi
fi

# Check if resource group exists, create if it doesn't
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
  echo "Creating resource group ${RESOURCE_GROUP} in ${LOCATION}..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

# Create app registration
APP_NAME="Indicator-Sync-App"
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
echo "CLIENT_ID=${APP_ID}" > indicator-app-credentials.env
echo "APP_OBJECT_ID=${OBJECT_ID}" >> indicator-app-credentials.env
echo "APP_NAME=${APP_NAME}" >> indicator-app-credentials.env

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
KV_NAME="indicator-kv-$(tr -dc 'a-z0-9' < /dev/urandom | fold -w 8 | head -n 1)"
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
echo "KEYVAULT_NAME=${KV_NAME}" >> indicator-app-credentials.env

# Assign Key Vault Secrets Officer role to the current user
echo -e "${BLUE}Assigning Key Vault permissions to current user...${NC}"
USER_ID=$(az ad signed-in-user show --query id -o tsv)
if [ -z "$USER_ID" ]; then
  echo -e "${RED}Unable to retrieve current user ID. Make sure you are logged in with az login.${NC}"
  exit 1
fi

echo "Granting Key Vault Secrets Officer role to current user..."
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee "$USER_ID" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
  || {
    echo -e "${RED}Failed to assign Key Vault role. You may need to manually assign permissions.${NC}"
    echo -e "${YELLOW}Manual steps: Go to the Key Vault in Azure Portal, select Access Control (IAM), add yourself as 'Key Vault Secrets Officer'.${NC}"
  }

# Wait for permissions to propagate
echo "Waiting 15 seconds for RBAC permissions to propagate..."
sleep 15

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
echo -e "Client secret has been securely stored in Key Vault and will be used by the Logic App."

echo -e "\n${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo "1. Grant admin consent for API permissions in the Azure Portal:"
echo "   - Navigate to: Microsoft Entra ID > App registrations"
echo "   - Select your app: ${APP_NAME}"
echo "   - Go to 'API permissions'"
echo "   - Click 'Grant admin consent for <your-tenant>'"

echo -e "\n2. Deploy the Indicator Sync solution using the following parameters:"
echo "   - Application (Client) ID: ${APP_ID}"
echo "   - Key Vault Name: ${KV_NAME}"
echo "   - Secret Name: IndicatorAppSecret"

echo -e "\n${YELLOW}IMPORTANT: When piping this script directly from curl, use:${NC}"
echo "curl -sL https://raw.githubusercontent.com/DataGuys/CTIBase/refs/heads/main/scripts/create-mde-app-registration.sh | bash -s -- --resource-group YOUR_RG_NAME --location YOUR_LOCATION"
echo -e "\nYour app registration and Key Vault details have been saved to: indicator-app-credentials.env"
echo -e "${YELLOW}NOTE: Your client secret has been securely stored in Key Vault and is NOT in the credentials file.${NC}"
