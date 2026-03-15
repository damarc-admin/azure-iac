# Azure IaC Deployment Script for Project Tracker (PowerShell)

$ErrorActionPreference = "Stop"

# Configuration
$ResourceGroup = "project-tracker-rg"
$Location = "eastus"
$DeploymentName = "project-tracker-deployment"

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Login check
Write-Host "Checking Azure login..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Please login to Azure..." -ForegroundColor Yellow
    az login
}

# Create resource group
Write-Host "Creating resource group..." -ForegroundColor Cyan
$existingRg = az group show --name $ResourceGroup 2>$null
if (-not $existingRg) {
    az group create --name $ResourceGroup --location $Location
    Write-Host "Resource group created." -ForegroundColor Green
} else {
    Write-Host "Resource group already exists." -ForegroundColor Yellow
}

# Deploy Bicep template
Write-Host "Deploying Azure resources..." -ForegroundColor Cyan
az deployment group create `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --template-file main.bicep `
    --parameters parameters.json

# Get the public IP address
Write-Host "Getting public IP address..." -ForegroundColor Cyan
$publicIp = az network public-ip show `
    --resource-group $ResourceGroup `
    --name project-tracker-lb-pip `
    --query ipAddress `
    --output tsv

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Access the application at: http://$publicIp" -ForegroundColor Cyan
Write-Host ""
Write-Host "To check VM status:" -ForegroundColor Yellow
Write-Host "  az vm show -g $ResourceGroup -n project-tracker-vm" -ForegroundColor Gray
