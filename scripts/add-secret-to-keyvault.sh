#!/bin/bash
# Script to add the MDE app client secret to Key Vault
set -e

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n======================================================="
echo "     Add MDE App Secret to Key Vault"
echo "======================================================="

# Check if environment file exists
ENV_FILE="mde-app-credentials.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: $ENV_FILE not found${NC}"
    echo "Please run this script from the same directory as the mde-app-credentials.env file"
    echo "or provide the path to this file when running the script."
    exit 1
fi

# Source the environment file to get CLIENT_SECRET
source "$ENV_FILE"

if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}Error: CLIENT_SECRET not found in $ENV_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Please provide your Key Vault name:${NC}"
read -p "Key Vault Name: " KEY_VAULT_NAME

if [ -z "$KEY_VAULT_NAME" ]; then
    echo -e "${RED}Error: Key Vault name is required${NC}"
    exit 1
fi

echo -e "${BLUE}Checking prerequisites...${NC}"
if ! az account show &> /dev/null; then
  echo -e "${YELLOW}Not logged in to Azure.${NC}"
  az login
fi

# Check if Key Vault exists
echo "Checking if Key Vault exists..."
if ! az keyvault show --name "$KEY_VAULT_NAME" &> /dev/null; then
    echo -e "${RED}Error: Key Vault '$KEY_VAULT_NAME' not found${NC}"
    exit 1
fi

echo "Adding client secret to Key Vault..."
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "MDEAppSecret" --value "$CLIENT_SECRET" --output none

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Success: Secret 'MDEAppSecret' added to Key Vault '$KEY_VAULT_NAME'${NC}"
else
    echo -e "${RED}Error: Failed to add secret to Key Vault${NC}"
    exit 1
fi

echo -e "\n${GREEN}Client secret has been successfully added to Key Vault.${NC}"
echo "The Logic App will now be able to access the secret to authenticate with the Microsoft Defender for Endpoint API."
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Check that the Logic App is running successfully."
echo "2. Verify that indicators are being synchronized to the Log Analytics workspace."
echo "3. Open the workbook to view and manage indicators."
