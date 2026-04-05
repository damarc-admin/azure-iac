#!/bin/bash

# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker
# =============================================================================
# Deploys infrastructure to the specified cloud provider using Terraform.
# On deployment failure, automatically cleans up (destroys) created resources.
#
# Usage:
#   ./deploy.sh <provider> [command]
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

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"

# Capture deployment metadata for tagging
DEPLOYED_BY="${USERNAME:-${USER:-unknown}}"
DEPLOYED_DATE="$(date +%Y-%m-%d)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

START_TIME=$(date +%s)

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# =============================================================================
# Help Display
# =============================================================================

show_help() {
    echo ""
    echo "Multi-Cloud Deployment Script - Project Tracker"
    echo ""
    echo "Usage: $0 <provider> [command]"
    echo ""
    echo "Providers:"
    echo "  aws      Deploy to Amazon Web Services"
    echo "  azure    Deploy to Microsoft Azure"
    echo "  gcp      Deploy to Google Cloud Platform"
    echo ""
    echo "Commands:"
    echo "  apply    Deploy resources (default) - auto-cleanup on failure"
    echo "  plan     Show deployment plan"
    echo "  destroy  Delete all resources"
    echo "  output   Show deployment outputs"
    echo ""
    echo "Examples:"
    echo "  $0 aws        # Deploy to AWS"
    echo "  $0 azure      # Deploy to Azure"
    echo "  $0 gcp        # Deploy to GCP"
    echo "  $0 aws plan   # Show AWS plan"
    echo "  $0 aws destroy # Delete AWS resources"
    echo ""
    echo "Deployment Info:"
    echo "  Deployed By: $DEPLOYED_BY"
    echo "  Deployed Date: $DEPLOYED_DATE"
    echo ""
}

# =============================================================================
# Prerequisites Check
# =============================================================================

check_prerequisites() {
    local cloud=$1
    
    # Terraform is required for all providers
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Install from: https://www.terraform.io/downloads"
        exit 1
    fi
    print_success "Terraform found"
    
    case "$cloud" in
        aws)
            if ! command -v aws &> /dev/null; then
                print_error "AWS CLI is not installed. Install from: https://aws.amazon.com/cli/"
                exit 1
            fi
            # Verify AWS credentials are configured
            if ! aws sts get-caller-identity &> /dev/null; then
                print_error "AWS credentials not configured. Run 'aws configure' first."
                exit 1
            fi
            print_success "AWS credentials configured"
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                print_error "Azure CLI is not installed. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
                exit 1
            fi
            # Verify Azure login
            if ! az account show &> /dev/null; then
                print_error "Not logged into Azure. Run 'az login' first."
                exit 1
            fi
            print_success "Azure subscription accessible"
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                print_error "Google Cloud SDK is not installed. Install from: https://cloud.google.com/sdk/docs/install"
                exit 1
            fi
            # Verify GCP credentials
            if ! gcloud auth list --filter=status:ACTIVE &> /dev/null; then
                print_error "GCP credentials not configured. Run 'gcloud auth login' first."
                exit 1
            fi
            print_success "GCP credentials configured"
            ;;
    esac
}

# =============================================================================
# Terraform Operations
# =============================================================================

run_terraform() {
    local cloud=$1
    local command=$2
    local config_file="main-${cloud}.tf"
    local varfile="${cloud}.tfvars"
    
    print_header "${cloud^^} - ${command}"
    echo -e "Deployed By: ${YELLOW}$DEPLOYED_BY${NC}"
    echo -e "Deployed Date: ${YELLOW}$DEPLOYED_DATE${NC}"
    echo ""
    
    # Validate config files exist
    if [ ! -f "$TERRAFORM_DIR/${config_file}" ]; then
        print_error "Config file not found: ${config_file}"
        return 1
    fi
    
    if [ ! -f "$TERRAFORM_DIR/${varfile}" ]; then
        print_error "Variable file not found: ${varfile}"
        return 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Remove other config files to avoid provider conflicts
    # Only the cloud-specific config should be present during terraform init
    for f in main.tf main-aws.tf main-azure.tf main-gcp.tf variables.tf; do
        if [ "$f" != "$config_file" ] && [ -f "$f" ]; then
            rm -f "$f"
        fi
    done
    
    # Initialize Terraform with the cloud-specific provider
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    if ! terraform init -upgrade; then
        print_error "Terraform init failed"
        return 1
    fi
    print_success "Terraform initialized"
    
    # Execute the requested command
    case "$command" in
        plan)
            echo -e "${YELLOW}Generating execution plan...${NC}"
            terraform plan -var-file="${varfile}" -var="deployed_by=${DEPLOYED_BY}" -var="deployed_date=${DEPLOYED_DATE}"
            return $?
            ;;
        apply)
            echo -e "${YELLOW}Creating execution plan...${NC}"
            if ! terraform plan -var-file="${varfile}" -var="deployed_by=${DEPLOYED_BY}" -var="deployed_date=${DEPLOYED_DATE}" -out=tfplan; then
                print_error "Plan generation failed"
                return 1
            fi
            
            echo -e "${YELLOW}Applying deployment...${NC}"
            if ! terraform apply tfplan; then
                print_error "Deployment failed"
                return 1
            fi
            
            print_success "Deployment completed successfully"
            terraform output
            return 0
            ;;
        destroy)
            read -p "This will destroy ALL ${cloud^^} resources. Type 'yes' to confirm: " confirm
            if [ "$confirm" != "yes" ]; then
                echo -e "${YELLOW}Destroy cancelled.${NC}"
                return 1
            fi
            
            echo -e "${YELLOW}Destroying ${cloud} resources...${NC}"
            terraform destroy -var-file="${varfile}" -var="deployed_by=${DEPLOYED_BY}" -var="deployed_date=${DEPLOYED_DATE}" -auto-approve
            return $?
            ;;
        output)
            terraform output
            return $?
            ;;
        *)
            print_error "Unknown command: $command"
            return 1
            ;;
    esac
}

# =============================================================================
# Cleanup on Failure
# =============================================================================

cleanup_on_failure() {
    local cloud=$1
    local varfile="${cloud}.tfvars"
    
    print_header "CLEANUP - Removing Failed Resources"
    print_warning "Deployment failed. Initiating automatic cleanup..."
    
    # Attempt to destroy resources created during failed deployment
    echo -e "${YELLOW}Running terraform destroy...${NC}"
    if terraform destroy -var-file="$varfile" -var="deployed_by=${DEPLOYED_BY}" -var="deployed_date=${DEPLOYED_DATE}" -auto-approve; then
        print_success "Cleanup completed successfully"
    else
        print_error "Cleanup failed. You may need to manually remove resources."
        echo -e "Check your ${cloud^^} console for any orphaned resources." "${YELLOW}"
    fi
}

# =============================================================================
# Print Deployment Time
# =============================================================================

print_deployment_time() {
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local MINUTES=$((ELAPSED / 60))
    local SECONDS=$((ELAPSED % 60))
    echo ""
    echo -e "Total time: ${GREEN}${MINUTES}m ${SECONDS}s${NC}"
    echo ""
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    local cloud=${1:-help}
    local command=${2:-apply}
    
    if [ "$cloud" = "help" ] || [ "$cloud" = "-h" ]; then
        show_help
        exit 0
    fi
    
    # Validate cloud provider
    case "$cloud" in
        aws|azure|gcp)
            ;;
        *)
            print_error "Unknown cloud: $cloud"
            show_help
            exit 1
            ;;
    esac
    
    print_header "Starting ${cloud^^} Deployment"
    echo -e "User: ${YELLOW}$DEPLOYED_BY${NC}"
    echo -e "Date: ${YELLOW}$DEPLOYED_DATE${NC}"
    echo ""
    
    # Check prerequisites before deployment
    check_prerequisites "$cloud"
    
    # Run the deployment with error handling
    if run_terraform "$cloud" "$command"; then
        if [ "$command" = "apply" ]; then
            print_header "Deployment Complete!"
            print_deployment_time
        fi
    else
        if [ "$command" = "apply" ]; then
            # Calculate time before cleanup
            local END_TIME=$(date +%s)
            local ELAPSED=$((END_TIME - START_TIME))
            local MINUTES=$((ELAPSED / 60))
            local SECONDS=$((ELAPSED % 60))
            
            print_header "Deployment Failed"
            echo -e "Time before failure: ${YELLOW}${MINUTES}m ${SECONDS}s${NC}"
            
            # Invoke cleanup
            cleanup_on_failure "$cloud"
        fi
        exit 1
    fi
}

main "$@"
