#!/bin/bash

# Azure IaC Deployment Script for Project Tracker

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Configuration
RESOURCE_GROUP="project-tracker-rg"
LOCATION="eastus"
DEPLOYMENT_NAME="project-tracker-deployment"

# Login check
echo "Checking Azure login..."
az account show > /dev/null 2>&1 || az login

# Create resource group
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy Bicep template
echo "Deploying Azure resources..."
az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --name $DEPLOYMENT_NAME \
    --template-file main.bicep \
    --parameters parameters.json \
    --verbose

# Get the public IP address
echo "Getting public IP address..."
PUBLIC_IP=$(az network public-ip show \
    --resource-group $RESOURCE_GROUP \
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
echo ""
echo "To check application logs:"
echo "  az vm extension show -g $RESOURCE_GROUP -n project-tracker-vm --vm-name project-tracker-vm --name install-app"
