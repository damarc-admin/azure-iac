# Azure IaC Deployment Script for Project Tracker (PowerShell)

$ErrorActionPreference = "Stop"

$ResourceGroup = "project-tracker-rg"
$Location = "canadacentral"
$DeploymentName = "project-tracker-deployment"
$ScriptDir = $PSScriptRoot

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed." -ForegroundColor Red
    exit 1
}

Write-Host "Checking Azure login..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Please login to Azure..." -ForegroundColor Yellow
    az login
}

Write-Host "Creating resource group..." -ForegroundColor Cyan
$existingRg = az group show --name $ResourceGroup 2>$null
if (-not $existingRg) {
    az group create --name $ResourceGroup --location $Location --output none
}

Write-Host "Deploying Azure resources..." -ForegroundColor Cyan
az deployment group create `
    --resource-group $ResourceGroup `
    --name $DeploymentName `
    --template-file "$ScriptDir\main.bicep" `
    --parameters "$ScriptDir\parameters.json" `
    --output table

Write-Host "Getting public IP..." -ForegroundColor Cyan
$publicIp = az network public-ip show `
    --resource-group $ResourceGroup `
    --name project-tracker-pip `
    --query ipAddress `
    --output tsv

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Access the application at: http://$publicIp`:5000" -ForegroundColor Cyan
