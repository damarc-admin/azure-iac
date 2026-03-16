# Azure IaC Deployment Script for Project Tracker (PowerShell)

$ErrorActionPreference = "Stop"

$ResourceGroup = "project-tracker-rg"
$Location = "canadacentral"
$DeploymentName = "project-tracker-deployment"
$ScriptDir = $PSScriptRoot

# Record start time
$StartTime = Get-Date

if ($args -contains "-Cleanup" -or $args -contains "-c") {
    Write-Host "Deleting resource group..." -ForegroundColor Yellow
    az group delete --name $ResourceGroup --yes --no-wait
    Write-Host "Resource group '$ResourceGroup' marked for deletion." -ForegroundColor Green
    exit 0
}

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

$existingRg = az group show --name $ResourceGroup 2>$null
if ($existingRg) {
    $rgLocation = ($existingRg | ConvertFrom-Json).location
    if ($rgLocation -ne $Location) {
        Write-Host "Deleting resource group in wrong location ($rgLocation)..." -ForegroundColor Yellow
        az group delete --name $ResourceGroup --yes --no-wait
        Start-Sleep -Seconds 10
    } else {
        Write-Host "Deleting existing public IP if exists..." -ForegroundColor Cyan
        az network public-ip delete --resource-group $ResourceGroup --name project-tracker-pip 2>$null
    }
}

Write-Host "Creating resource group..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location --output none

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

# Calculate elapsed time
$EndTime = Get-Date
$Elapsed = $EndTime - $StartTime
$Minutes = [math]::Floor($Elapsed.TotalMinutes)
$Seconds = [math]::Round($Elapsed.TotalSeconds % 60)

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Access the application at: http://$publicIp`:5000" -ForegroundColor Cyan
Write-Host "Total deployment time: ${Minutes}m ${Seconds}s" -ForegroundColor Yellow
