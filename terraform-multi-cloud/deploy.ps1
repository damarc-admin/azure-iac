# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker (PowerShell)
# =============================================================================
# Deploys the Project Tracker application to the specified cloud provider
#
# Usage:
#   .\deploy.ps1 aws      # Deploy to AWS
#   .\deploy.ps1 azure   # Deploy to Azure
#   .\deploy.ps1 gcp      # Deploy to GCP
#   .\deploy.ps1 all      # Deploy to all clouds
#   .\deploy.ps1 destroy  # Destroy all resources
#   .\deploy.ps1 help     # Show help
# =============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("aws", "azure", "gcp", "all", "destroy", "help")]
    [string]$Cloud = "help",
    
    [Parameter(Position = 1)]
    [ValidateSet("plan", "deploy", "destroy", "output")]
    [string]$Command = "deploy"
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$TerraformDir = $ScriptDir

$StartTime = Get-Date

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning-Message {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

function Show-Help {
    Write-Host @"
Multi-Cloud Deployment Script - Project Tracker

Usage: .\deploy.ps1 <provider> [command]

Providers:
  aws      Deploy to Amazon Web Services
  azure    Deploy to Microsoft Azure
  gcp      Deploy to Google Cloud Platform
  all      Deploy to all enabled clouds
  destroy  Destroy all resources

Commands:
  (none)   Deploy resources
  plan     Show deployment plan
  destroy  Delete all resources
  output   Show deployment outputs

Examples:
  .\deploy.ps1 aws        # Deploy to AWS
  .\deploy.ps1 azure      # Deploy to Azure
  .\deploy.ps1 gcp        # Deploy to GCP
  .\deploy.ps1 all plan   # Show plan for all clouds
  .\deploy.ps1 aws destroy # Delete AWS resources

"@
}

# -----------------------------------------------------------------------------
# Prerequisites Check
# -----------------------------------------------------------------------------

function Test-Prerequisites {
    param([string]$Provider)
    
    switch ($Provider) {
        "aws" {
            if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
                Write-Error-Message "AWS CLI is not installed."
                exit 1
            }
            Write-Success "AWS CLI found"
        }
        "azure" {
            if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                Write-Error-Message "Azure CLI is not installed."
                exit 1
            }
            Write-Success "Azure CLI found"
        }
        "gcp" {
            if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
                Write-Error-Message "Google Cloud SDK is not installed."
                exit 1
            }
            Write-Success "Google Cloud SDK found"
        }
    }
}

# -----------------------------------------------------------------------------
# Terraform Init
# -----------------------------------------------------------------------------

function Initialize-Terraform {
    Write-Header "Initializing Terraform"
    Set-Location $TerraformDir
    terraform init
}

# -----------------------------------------------------------------------------
# Deploy to Cloud
# -----------------------------------------------------------------------------

function Deploy-Cloud {
    param([string]$Provider)
    
    $varfile = "$Provider.tfvars"
    
    Write-Header "Deploying to $($Provider.ToUpper())"
    
    if (-not (Test-Path "$TerraformDir\$varfile")) {
        Write-Error-Message "Configuration file not found: $varfile"
        return
    }
    
    if (-not (Test-Path "$TerraformDir\.terraform")) {
        Initialize-Terraform
    }
    
    Set-Location $TerraformDir
    
    Write-Warning-Message "Creating deployment plan..."
    terraform plan -var-file="$varfile" -out=tfplan
    
    Write-Warning-Message "Applying deployment..."
    terraform apply tfplan
    
    Write-Header "Deployment Outputs"
    terraform output
}

# -----------------------------------------------------------------------------
# Plan Cloud
# -----------------------------------------------------------------------------

function Plan-Cloud {
    param([string]$Provider)
    
    $varfile = "$Provider.tfvars"
    
    Write-Header "Planning $($Provider.ToUpper()) Deployment"
    
    if (-not (Test-Path "$TerraformDir\$varfile")) {
        Write-Error-Message "Configuration file not found: $varfile"
        return
    }
    
    if (-not (Test-Path "$TerraformDir\.terraform")) {
        Initialize-Terraform
    }
    
    Set-Location $TerraformDir
    terraform plan -var-file="$varfile"
}

# -----------------------------------------------------------------------------
# Destroy Cloud
# -----------------------------------------------------------------------------

function Destroy-Cloud {
    param([string]$Provider)
    
    $varfile = "$Provider.tfvars"
    
    Write-Header "Destroying $($Provider.ToUpper()) Resources"
    
    if (-not (Test-Path "$TerraformDir\$varfile")) {
        Write-Error-Message "Configuration file not found: $varfile"
        return
    }
    
    Set-Location $TerraformDir
    terraform destroy -var-file="$varfile"
}

# -----------------------------------------------------------------------------
# Show Output
# -----------------------------------------------------------------------------

function Show-Output {
    param([string]$Provider)
    
    Write-Header "$($Provider.ToUpper()) Outputs"
    Set-Location $TerraformDir
    terraform output deployment_summary
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Handle help
if ($Cloud -eq "help") {
    Show-Help
    exit 0
}

# Handle destroy all
if ($Cloud -eq "destroy") {
    Write-Warning-Message "This will destroy resources in ALL clouds."
    $confirm = Read-Host "Are you sure? Type 'yes' to confirm"
    if ($confirm -eq "yes") {
        Destroy-Cloud "aws"
        Destroy-Cloud "azure"
        Destroy-Cloud "gcp"
    }
    exit 0
}

# Validate cloud
$validClouds = @("aws", "azure", "gcp", "all")
if ($Cloud -notin $validClouds) {
    Write-Error-Message "Unknown cloud provider: $Cloud"
    Write-Host "Valid options: aws, azure, gcp, all, destroy, help" -ForegroundColor Yellow
    exit 1
}

# Check prerequisites
if ($Cloud -ne "all") {
    Test-Prerequisites $Cloud
} else {
    Test-Prerequisites "aws"
    Test-Prerequisites "azure"
    Test-Prerequisites "gcp"
}

# Execute command
switch ($Command) {
    "plan" {
        if ($Cloud -eq "all") {
            Plan-Cloud "aws"
            Plan-Cloud "azure"
            Plan-Cloud "gcp"
        } else {
            Plan-Cloud $Cloud
        }
    }
    "destroy" {
        if ($Cloud -eq "all") {
            $confirm = Read-Host "Destroy all clouds? Type 'yes'"
            if ($confirm -eq "yes") {
                Destroy-Cloud "aws"
                Destroy-Cloud "azure"
                Destroy-Cloud "gcp"
            }
        } else {
            Destroy-Cloud $Cloud
        }
    }
    "output" {
        Show-Output $Cloud
    }
    "deploy" {
        if ($Cloud -eq "all") {
            Deploy-Cloud "aws"
            Deploy-Cloud "azure"
            Deploy-Cloud "gcp"
        } else {
            Deploy-Cloud $Cloud
        }
        
        # Print deployment time
        $EndTime = Get-Date
        $Elapsed = $EndTime - $StartTime
        $Minutes = [math]::Floor($Elapsed.TotalMinutes)
        $Seconds = [math]::Round($Elapsed.TotalSeconds % 60)
        
        Write-Header "Deployment Complete!"
        Write-Host "Total time: ${Minutes}m ${Seconds}s" -ForegroundColor Green
    }
}
