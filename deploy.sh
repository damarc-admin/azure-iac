#!/bin/bash

set -e

RESOURCE_GROUP="project-tracker-rg"
LOCATION="canadacentral"
DEPLOYMENT_NAME="project-tracker-deployment"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$1" = "--cleanup" ] || [ "$1" = "-c" ]; then
    echo "Deleting resource group..."
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait
    echo "Resource group '$RESOURCE_GROUP' marked for deletion."
    exit 0
fi

echo "Checking Azure CLI..."
az account show > /dev/null 2>&1 || az login

EXISTING_RG=$(az group show --name "$RESOURCE_GROUP" 2>/dev/null || echo "")
if [ -n "$EXISTING_RG" ]; then
    RG_LOCATION=$(echo "$EXISTING_RG" | jq -r '.location')
    if [ "$RG_LOCATION" != "$LOCATION" ]; then
        echo "Deleting resource group in wrong location ($RG_LOCATION)..."
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        sleep 10
    else
        echo "Deleting existing public IP if exists..."
        az network public-ip delete --resource-group "$RESOURCE_GROUP" --name project-tracker-pip 2>/dev/null || true
    fi
fi

echo "Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

echo "Deploying Azure resources..."
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$SCRIPT_DIR/main.bicep" \
    --parameters "$SCRIPT_DIR/parameters.json" \
    --output table

echo "Getting public IP..."
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name project-tracker-pip \
    --query ipAddress \
    --output tsv)

echo ""
echo "==================================="
echo "Deployment Complete!"
echo "==================================="
echo "Access the application at: http://$PUBLIC_IP:5000"
echo ""
echo "To check VM status:"
echo "  az vm show -g $RESOURCE_GROUP -n project-tracker-vm"
