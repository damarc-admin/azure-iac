# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker (PowerShell)
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
  azure   Deploy to Microsoft Azure
  gcp     Deploy to Google Cloud Platform

Commands:
  apply    Deploy resources (default)
  plan     Show deployment plan
  destroy  Delete all resources
  output   Show deployment outputs

Examples:
  .\deploy.ps1 aws        # Deploy to AWS
  .\deploy.ps1 azure     # Deploy to Azure
  .\deploy.ps1 gcp       # Deploy to GCP
  .\deploy.ps1 aws plan  # Show AWS plan
  .\deploy.ps1 aws destroy # Delete AWS resources

"@
}

function Test-Prerequisites {
    param([string]$Provider)
    
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform is not installed."
        exit 1
    }
    
    switch ($Provider) {
        "aws" {
            if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
                Write-Error "AWS CLI is not installed."
                exit 1
            }
            Write-Success "AWS CLI found"
        }
        "azure" {
            if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                Write-Error "Azure CLI is not installed."
                exit 1
            }
            Write-Success "Azure CLI found"
        }
        "gcp" {
            if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
                Write-Error "Google Cloud SDK is not installed."
                exit 1
            }
            Write-Success "Google Cloud SDK found"
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
    
    if (-not (Test-Path "$ScriptDir\$configFile")) {
        Write-Error "Config file not found: $configFile"
        return
    }
    
    if (-not (Test-Path "$ScriptDir\$varFile")) {
        Write-Error "Variable file not found: $varFile"
        return
    }
    
    Set-Location $ScriptDir
    
    # Remove other config files
    @("main.tf", "main-aws.tf", "main-azure.tf", "main-gcp.tf") | ForEach-Object {
        if ($_ -ne $configFile -and (Test-Path $_)) {
            Remove-Item $_ -Force
        }
    }
    
    terraform init -upgrade
    
    switch ($Command) {
        "plan" {
            terraform plan -var-file=$varFile
        }
        "apply" {
            terraform plan -var-file=$varFile -out=tfplan
            terraform apply tfplan
            terraform output
        }
        "destroy" {
            $confirm = Read-Host "Destroy ${Cloud} resources? Type 'yes'"
            if ($confirm -eq "yes") {
                terraform destroy -var-file=$varFile
            }
        }
        "output" {
            terraform output
        }
    }
}

# Main
if ($Cloud -eq "help") {
    Show-Help
    exit 0
}

Test-Prerequisites $Cloud
Invoke-Terraform -Cloud $Cloud -Command $Command

if ($Command -eq "apply") {
    $EndTime = Get-Date
    $Elapsed = $EndTime - $StartTime
    $Minutes = [math]::Floor($Elapsed.TotalMinutes)
    $Seconds = [math]::Round($Elapsed.TotalSeconds % 60)
    
    Write-Header "Deployment Complete!"
    Write-Host "Total time: ${Minutes}m ${Seconds}s" -ForegroundColor Green
}
