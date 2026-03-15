#!/bin/bash

set -e

RESOURCE_GROUP="project-tracker-rg"
LOCATION="eastus"
DEPLOYMENT_NAME="project-tracker-deployment"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Checking Azure CLI..."
az account show > /dev/null 2>&1 || az login

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
    --name project-tracker-lb-pip \
    --query ipAddress \
    --output tsv)

echo ""
echo "==================================="
echo "Deployment Complete!"
echo "==================================="
echo "Access the application at: http://$PUBLIC_IP"
echo ""
echo "To check VM status:"
echo "  az vm show -g $RESOURCE_GROUP -n project-tracker-vm"
