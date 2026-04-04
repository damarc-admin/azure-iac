#!/bin/bash

# =============================================================================
# Terraform Deployment Script - Project Tracker
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
#   ./deploy.sh          - Deploy resources
#   ./deploy.sh --help   - Show this help message
#   ./deploy.sh --cleanup - Delete all deployed resources
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================

# Resource group and location configuration
# These should match the values in terraform.tfvars
RESOURCE_GROUP="project-tracker-rg"
LOCATION="canadacentral"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

# Print a section header
print_header() {
    echo ""
    echo "======================================"
    echo "$1"
    echo "======================================"
    echo ""
}

# Print an error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# =============================================================================
# Cleanup Function
# =============================================================================

cleanup() {
    print_header "Cleanup Mode"
    echo "This will delete ALL resources in the resource group."
    echo "Resource Group: $RESOURCE_GROUP"
    echo ""
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Destroying Terraform-managed resources..."
        cd "$TERRAFORM_DIR"
        terraform destroy -auto-approve
        echo "Cleanup complete."
    else
        echo "Cleanup cancelled."
    fi
    exit 0
}

# =============================================================================
# Main Deployment
# =============================================================================

# Check for cleanup flag
if [ "$1" = "--cleanup" ] || [ "$1" = "-c" ]; then
    cleanup
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cleanup, -c    Delete all deployed resources"
    echo "  --help, -h       Show this help message"
    echo ""
    exit 0
fi

# Record start time for deployment duration calculation
START_TIME=$(date +%s)

# Print banner
print_header "Project Tracker - Terraform Deployment"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# =============================================================================
# Prerequisites Check
# =============================================================================

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    error_exit "Terraform is not installed.
    
Please install Terraform:
  - Download from: https://www.terraform.io/downloads
  - Or use: brew install terraform (macOS)
  - Or use: winget install HashiCorp.Terraform (Windows)"
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    error_exit "Azure CLI is not installed.

Please install Azure CLI:
  - Windows: winget install Microsoft.AzureCLI
  - macOS: brew install azure-cli
  - Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
fi

# Check Terraform version
TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
echo "Using Terraform version: $TERRAFORM_VERSION"

# =============================================================================
# Azure Authentication
# =============================================================================

print_header "Azure Authentication"

echo "Checking Azure login status..."
# Check if user is logged in, prompt login if not
az account show > /dev/null 2>&1 || az login

# Show current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo "Authenticated to Azure subscription: $SUBSCRIPTION"

# =============================================================================
# Configuration Setup
# =============================================================================

print_header "Configuration Setup"

# Create terraform.tfvars from example if it doesn't exist
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from example..."
    cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
    echo ""
    error_exit "Please edit terraform.tfvars and set your admin_password.
    
Run: nano terraform.tfvars
Then re-run this script."
fi

# Verify admin_password is set (not the placeholder)
ADMIN_PASSWORD=$(grep "admin_password" "$TERRAFORM_DIR/terraform.tfvars" | grep -v "^#" | cut -d'=' -f2 | tr -d ' "')
if [ -z "$ADMIN_PASSWORD" ] || [ "$ADMIN_PASSWORD" = "REPLACE_WITH_YOUR_PASSWORD" ]; then
    error_exit "admin_password is not set in terraform.tfvars.
    
Please edit terraform.tfvars and set a secure password."
fi

echo "Configuration file validated."

# =============================================================================
# Terraform Workflow
# =============================================================================

print_header "Terraform Initialization"

# Change to Terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform (downloads provider plugins)
echo "Initializing Terraform backend and providers..."
terraform init

# =============================================================================

print_header "Terraform Validation"

# Format code (ensures consistent style)
echo "Formatting Terraform files..."
terraform fmt

# Validate configuration (checks for syntax errors)
echo "Validating Terraform configuration..."
if ! terraform validate; then
    error_exit "Terraform configuration validation failed."
fi

# =============================================================================

print_header "Terraform Planning"

# Create execution plan
# -out=tfplan saves the plan to a file for use in apply
echo "Creating deployment plan..."
echo "This may take a few minutes..."
terraform plan -out=tfplan

# Show summary of changes
echo ""
echo "Plan created successfully."

# =============================================================================

print_header "Terraform Apply"

# Apply the plan
# -auto-approve skips interactive approval prompt
echo "Deploying resources to Azure..."
echo "This may take 5-10 minutes..."
terraform apply -auto-approve tfplan

# =============================================================================

print_header "Deployment Results"

# Display all outputs
echo "Deployment outputs:"
echo ""
terraform output

# =============================================================================
# Deployment Summary
# =============================================================================

# Calculate total deployment time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

# Get access URL
ACCESS_URL=$(terraform output -raw access_url 2>/dev/null || echo "http://<public-ip>:5000")

# Print summary
echo ""
print_header "Deployment Complete!"
echo ""
echo "Application URL: $ACCESS_URL"
echo "Total deployment time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "Next steps:"
echo "  1. Open the URL above in your browser"
echo "  2. SSH into VM: $(terraform output -raw ssh_connection 2>/dev/null || echo 'ssh azureuser@<ip>')"
echo "  3. View app logs: az vm run-command invoke -g $RESOURCE_GROUP -n project-tracker-vm --command-id RunShellScript --script 'journalctl -u project-tracker'"
echo ""
echo "To clean up all resources:"
echo "  $0 --cleanup"
