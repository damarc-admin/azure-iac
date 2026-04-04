# =============================================================================
# Terraform Deployment Script - Project Tracker (PowerShell)
# =============================================================================
# Purpose: Automate the deployment of Project Tracker application to Azure
#
# This script handles the complete Terraform workflow:
#   1. Prerequisites check (Terraform, Azure CLI)
#   2. Azure authentication
#   3. Configuration validation
#   4. Terraform initialization and planning
#   5. Resource deployment
#   6. Output retrieval
#
# Usage:
#   .\deploy.ps1         - Deploy resources
#   .\deploy.ps1 -Help   - Show this help message
#   .\deploy.ps1 -Cleanup - Delete all deployed resources
# =============================================================================

[CmdletBinding()]
param(
    # Cleanup flag: Delete all deployed resources
    [Parameter(Position = 0)]
    [switch]$Cleanup,
    
    # Help flag: Show usage information
    [switch]$Help
)

# =============================================================================
# Configuration
# =============================================================================

# Resource group and location configuration
# These should match the values in terraform.tfvars
$ResourceGroup = "project-tracker-rg"
$Location = "canadacentral"

# Get the directory where this script is located
$ScriptDir = $PSScriptRoot

# =============================================================================
# Helper Functions
# =============================================================================

function Write-Banner {
    param([string]$Message)
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "Error: $Message" -ForegroundColor Red
}

# =============================================================================
# Cleanup Function
# =============================================================================

function Invoke-Cleanup {
    Write-Banner "Cleanup Mode"
    Write-Host "This will delete ALL resources in the resource group." -ForegroundColor Yellow
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Are you sure? Type 'yes' to confirm"
    if ($confirm -eq "yes") {
        Write-Host "Destroying Terraform-managed resources..." -ForegroundColor Cyan
        Set-Location $ScriptDir
        terraform destroy -auto-approve
        Write-Host "Cleanup complete." -ForegroundColor Green
    }
    else {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    }
    exit 0
}

# =============================================================================
# Display Help
# =============================================================================

function Show-Help {
    Write-Host @"
Terraform Deployment Script - Project Tracker

Usage:
    .\deploy.ps1 [-Cleanup] [-Help]

Options:
    -Cleanup    Delete all deployed resources instead of deploying
    -Help       Show this help message

Description:
    This script automates the deployment of the Project Tracker
    application to Azure using Terraform.

Examples:
    # Deploy resources
    .\deploy.ps1

    # Delete all resources
    .\deploy.ps1 -Cleanup

    # Show help
    .\deploy.ps1 -Help

"@
    exit 0
}

# =============================================================================
# Main Script
# =============================================================================

$ErrorActionPreference = "Stop"

# Handle -Help flag
if ($Help) {
    Show-Help
}

# Handle -Cleanup flag
if ($Cleanup) {
    Invoke-Cleanup
}

# Record start time for deployment duration calculation
$StartTime = Get-Date

# Print banner
Write-Banner "Project Tracker - Terraform Deployment"
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Prerequisites Check
# =============================================================================

# Check if Terraform is installed
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error-Message "Terraform is not installed."
    Write-Host ""
    Write-Host "Please install Terraform:" -ForegroundColor Yellow
    Write-Host "  - Download from: https://www.terraform.io/downloads" -ForegroundColor Gray
    Write-Host "  - Windows: winget install HashiCorp.Terraform" -ForegroundColor Gray
    Write-Host "  - macOS: brew install terraform" -ForegroundColor Gray
    exit 1
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error-Message "Azure CLI is not installed."
    Write-Host ""
    Write-Host "Please install Azure CLI:" -ForegroundColor Yellow
    Write-Host "  - Windows: winget install Microsoft.AzureCLI" -ForegroundColor Gray
    Write-Host "  - macOS: brew install azure-cli" -ForegroundColor Gray
    exit 1
}

# Check Terraform version
$TerraformVersion = terraform version 2>$null | Select-Object -First 1
Write-Host "Using: $TerraformVersion" -ForegroundColor Gray

# =============================================================================
# Azure Authentication
# =============================================================================

Write-Banner "Azure Authentication"

Write-Host "Checking Azure login status..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json

if (-not $account) {
    Write-Host "Please login to Azure..." -ForegroundColor Yellow
    az login
    $account = az account show 2>$null | ConvertFrom-Json
}

Write-Host "Authenticated to Azure subscription: $($account.name)" -ForegroundColor Green

# =============================================================================
# Configuration Setup
# =============================================================================

Write-Banner "Configuration Setup"

$tfvarsPath = Join-Path $ScriptDir "terraform.tfvars"
$tfvarsExamplePath = Join-Path $ScriptDir "terraform.tfvars.example"

# Create terraform.tfvars from example if it doesn't exist
if (-not (Test-Path $tfvarsPath)) {
    Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Yellow
    Copy-Item $tfvarsExamplePath $tfvarsPath
    Write-Host ""
    Write-Error-Message "Please edit terraform.tfvars and set your admin_password."
    Write-Host "Run: notepad terraform.tfvars" -ForegroundColor Yellow
    Write-Host "Then re-run this script." -ForegroundColor Yellow
    exit 1
}

# Verify admin_password is set (not the placeholder)
$tfvarsContent = Get-Content $tfvarsPath -Raw
if ($tfvarsContent -match 'admin_password\s*=\s*"REPLACE_WITH_YOUR_PASSWORD"') {
    Write-Error-Message "admin_password is not set in terraform.tfvars."
    Write-Host "Please edit terraform.tfvars and set a secure password." -ForegroundColor Yellow
    exit 1
}

Write-Host "Configuration file validated." -ForegroundColor Green

# =============================================================================
# Terraform Workflow
# =============================================================================

Write-Banner "Terraform Initialization"

# Change to Terraform directory
Set-Location $ScriptDir

# Initialize Terraform (downloads provider plugins)
Write-Host "Initializing Terraform backend and providers..." -ForegroundColor Cyan
terraform init

# =============================================================================

Write-Banner "Terraform Validation"

# Format code (ensures consistent style)
Write-Host "Formatting Terraform files..." -ForegroundColor Cyan
terraform fmt

# Validate configuration (checks for syntax errors)
Write-Host "Validating Terraform configuration..." -ForegroundColor Cyan
$validation = terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Error-Message "Terraform configuration validation failed."
    exit 1
}
Write-Host "Validation successful." -ForegroundColor Green

# =============================================================================

Write-Banner "Terraform Planning"

# Create execution plan
Write-Host "Creating deployment plan..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Gray
terraform plan -out=tfplan

# Show summary of changes
Write-Host ""
Write-Host "Plan created successfully." -ForegroundColor Green

# =============================================================================

Write-Banner "Terraform Apply"

# Apply the plan
Write-Host "Deploying resources to Azure..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
terraform apply -auto-approve tfplan

# =============================================================================

Write-Banner "Deployment Results"

# Display all outputs
Write-Host "Deployment outputs:" -ForegroundColor Cyan
Write-Host ""
terraform output

# =============================================================================
# Deployment Summary
# =============================================================================

# Calculate total deployment time
$EndTime = Get-Date
$Elapsed = $EndTime - $StartTime
$Minutes = [math]::Floor($Elapsed.TotalMinutes)
$Seconds = [math]::Round($Elapsed.TotalSeconds % 60)

# Get access URL
$accessUrl = terraform output -raw access_url 2>$null
if (-not $accessUrl) {
    $accessUrl = "http://<public-ip>:5000"
}

# Get SSH connection
$sshConnection = terraform output -raw ssh_connection 2>$null
if (-not $sshConnection) {
    $sshConnection = "ssh azureuser@<public-ip>"
}

# Print summary
Write-Host ""
Write-Banner "Deployment Complete!"
Write-Host "Application URL: $accessUrl" -ForegroundColor Green
Write-Host "Total deployment time: ${Minutes}m ${Seconds}s" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open the URL above in your browser"
Write-Host "  2. SSH into VM: $sshConnection"
Write-Host "  3. View app logs:"
Write-Host "     az vm run-command invoke -g $ResourceGroup -n project-tracker-vm --command-id RunShellScript --script `"journalctl -u project-tracker`""
Write-Host ""
Write-Host "To clean up all resources:" -ForegroundColor Yellow
Write-Host "  .\deploy.ps1 -Cleanup" -ForegroundColor Gray
