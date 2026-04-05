# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker (PowerShell)
# =============================================================================
# Deploys infrastructure to the specified cloud provider using Terraform.
# On deployment failure, automatically cleans up (destroys) created resources.
#
# Usage:
#   .\deploy.ps1 <provider> [command]
#
# Providers:
#   aws      Deploy to Amazon Web Services
#   azure    Deploy to Microsoft Azure
#   gcp      Deploy to Google Cloud Platform
#
# Commands:
#   apply    Deploy resources (default) - auto-cleanup on failure
#   plan     Show deployment plan
#   destroy  Delete all resources
#   output   Show deployment outputs
# =============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("aws", "azure", "gcp", "help")]
    [string]$Cloud = "help",
    
    [Parameter(Position = 1)]
    [ValidateSet("plan", "apply", "destroy", "output")]
    [string]$Command = "apply"
)

$StartTime = Get-Date
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Capture deployment metadata for tagging
$DeployedBy = $env:USERNAME
$DeployedDate = (Get-Date -Format "yyyy-MM-dd")

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success { param([string]$M) Write-Host "✓ $M" -ForegroundColor Green }
function Write-Warning { param([string]$M) Write-Host "⚠ $M" -ForegroundColor Yellow }
function Write-Error { param([string]$M) Write-Host "✗ $M" -ForegroundColor Red }

function Show-Help {
    Write-Host @"
Multi-Cloud Deployment Script - Project Tracker

Usage: .\deploy.ps1 <provider> [command]

Providers:
  aws      Deploy to Amazon Web Services
  azure    Deploy to Microsoft Azure
  gcp      Deploy to Google Cloud Platform

Commands:
  apply    Deploy resources (default) - auto-cleanup on failure
  plan     Show deployment plan
  destroy  Delete all resources
  output   Show deployment outputs

Examples:
  .\deploy.ps1 aws        # Deploy to AWS
  .\deploy.ps1 azure     # Deploy to Azure
  .\deploy.ps1 gcp       # Deploy to GCP
  .\deploy.ps1 aws plan  # Show AWS plan
  .\deploy.ps1 aws destroy # Delete AWS resources

Deployment Info:
  Deployed By: $DeployedBy
  Deployed Date: $DeployedDate

"@
}

function Test-Prerequisites {
    param([string]$Provider)
    
    # Terraform is required for all providers
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is not installed. Install from: https://www.terraform.io/downloads"
        exit 1
    }
    Write-Success "Terraform found"
    
    # Provider-specific CLI check
    switch ($Provider) {
        "aws" {
            if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
                Write-Error "AWS CLI is not installed. Install from: https://aws.amazon.com/cli/"
                exit 1
            }
            # Verify AWS credentials are configured
            try {
                aws sts get-caller-identity | Out-Null
                Write-Success "AWS credentials configured"
            } catch {
                Write-Error "AWS credentials not configured. Run 'aws configure' first."
                exit 1
            }
        }
        "azure" {
            if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                Write-Error "Azure CLI is not installed. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
                exit 1
            }
            # Verify Azure login
            try {
                az account show | Out-Null
                Write-Success "Azure subscription accessible"
            } catch {
                Write-Error "Not logged into Azure. Run 'az login' first."
                exit 1
            }
        }
        "gcp" {
            if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
                Write-Error "Google Cloud SDK is not installed. Install from: https://cloud.google.com/sdk/docs/install"
                exit 1
            }
            # Verify GCP credentials
            try {
                gcloud auth list --filter=status:ACTIVE --format="value(account)" | Out-Null
                Write-Success "GCP credentials configured"
            } catch {
                Write-Error "GCP credentials not configured. Run 'gcloud auth login' first."
                exit 1
            }
        }
    }
}

function Invoke-Terraform {
    param(
        [string]$Cloud,
        [string]$Command
    )
    
    $configFile = "main-${Cloud}.tf"
    $varFile = "${Cloud}.tfvars"
    
    Write-Header "${Cloud.ToUpper()} - ${Command}"
    Write-Host "Deployed By: $DeployedBy" -ForegroundColor Gray
    Write-Host "Deployed Date: $DeployedDate" -ForegroundColor Gray
    Write-Host ""
    
    # Validate config files exist
    if (-not (Test-Path "$ScriptDir\$configFile")) {
        Write-Error "Config file not found: $configFile"
        return $false
    }
    
    if (-not (Test-Path "$ScriptDir\$varFile")) {
        Write-Error "Variable file not found: $varFile"
        return $false
    }
    
    Set-Location $ScriptDir
    
    # Remove other config files to avoid provider conflicts
    # Only the cloud-specific config should be present during terraform init
    @("main.tf", "main-aws.tf", "main-azure.tf", "main-gcp.tf", "variables.tf") | ForEach-Object {
        if ($_ -ne $configFile -and (Test-Path $_)) {
            Write-Verbose "Removing: $_"
            Remove-Item $_ -Force
        }
    }
    
    # Initialize Terraform with the cloud-specific provider
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init -upgrade
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform init failed"
        return $false
    }
    Write-Success "Terraform initialized"
    
    # Execute the requested command
    switch ($Command) {
        "plan" {
            Write-Host "Generating execution plan..." -ForegroundColor Yellow
            terraform plan -var-file=$varFile -var="deployed_by=$DeployedBy" -var="deployed_date=$DeployedDate"
            return ($LASTEXITCODE -eq 0)
        }
        "apply" {
            Write-Host "Creating execution plan..." -ForegroundColor Yellow
            terraform plan -var-file=$varFile -var="deployed_by=$DeployedBy" -var="deployed_date=$DeployedDate" -out=tfplan
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Plan generation failed"
                return $false
            }
            
            Write-Host "Applying deployment..." -ForegroundColor Yellow
            terraform apply tfplan
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Deployment failed"
                return $false
            }
            
            Write-Success "Deployment completed successfully"
            terraform output
            return $true
        }
        "destroy" {
            $confirm = Read-Host "This will destroy ALL ${Cloud} resources. Type 'yes' to confirm: "
            if ($confirm -ne "yes") {
                Write-Host "Destroy cancelled." -ForegroundColor Yellow
                return $false
            }
            
            Write-Host "Destroying ${Cloud} resources..." -ForegroundColor Yellow
            terraform destroy -var-file=$varFile -var="deployed_by=$DeployedBy" -var="deployed_date=$DeployedDate"
            return ($LASTEXITCODE -eq 0)
        }
        "output" {
            terraform output
            return ($LASTEXITCODE -eq 0)
        }
        default {
            Write-Error "Unknown command: $Command"
            return $false
        }
    }
}

function Invoke-Cleanup {
    param(
        [string]$Cloud,
        [string]$VarFile
    )
    
    Write-Header "CLEANUP - Removing Failed Resources"
    Write-Warning "Deployment failed. Initiating automatic cleanup..."
    
    try {
        # Attempt to destroy resources created during failed deployment
        Write-Host "Running terraform destroy..." -ForegroundColor Yellow
        terraform destroy -var-file=$VarFile -var="deployed_by=$DeployedBy" -var="deployed_date=$DeployedDate" -auto-approve
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Cleanup completed successfully"
        } else {
            Write-Error "Cleanup failed. You may need to manually remove resources."
            Write-Host "Check your ${Cloud} console for any orphaned resources." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "Cleanup encountered an error: $_"
        Write-Host "Please manually clean up resources in your ${Cloud} console." -ForegroundColor Yellow
    }
}

# Main execution
if ($Cloud -eq "help") {
    Show-Help
    exit 0
}

Write-Header "Starting ${Cloud.ToUpper()} Deployment"
Write-Host "User: $DeployedBy" -ForegroundColor Gray
Write-Host "Date: $DeployedDate" -ForegroundColor Gray
Write-Host ""

# Verify prerequisites before attempting deployment
Test-Prerequisites $Cloud

# Track whether we need cleanup (resources were partially created)
$resourcesCreated = $false
$success = $false

try {
    # Attempt the deployment
    $success = Invoke-Terraform -Cloud $Cloud -Command $Command
    
    if ($Command -eq "apply" -and $success) {
        $resourcesCreated = $true
    }
}
catch {
    Write-Error "Deployment error: $_"
    $success = $false
}

# Calculate elapsed time
$EndTime = Get-Date
$Elapsed = $EndTime - $StartTime
$Minutes = [math]::Floor($Elapsed.TotalMinutes)
$Seconds = [math]::Round($Elapsed.TotalSeconds % 60)

if ($Command -eq "apply") {
    if ($success) {
        Write-Header "Deployment Complete!"
        Write-Host "Total time: ${Minutes}m ${Seconds}s" -ForegroundColor Green
    }
    else {
        # Cleanup on failure only for apply command
        Write-Header "Deployment Failed"
        Write-Host "Total time before failure: ${Minutes}m ${Seconds}s" -ForegroundColor Yellow
        
        # Invoke cleanup
        Invoke-Cleanup -Cloud $Cloud -VarFile "${Cloud}.tfvars"
        exit 1
    }
}
