#!/bin/bash

# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker
# =============================================================================
# Deploys the Project Tracker application to the specified cloud provider
#
# Usage:
#   ./deploy.sh aws      # Deploy to AWS
#   ./deploy.sh azure   # Deploy to Azure
#   ./deploy.sh gcp      # Deploy to GCP
#   ./deploy.sh all      # Deploy to all clouds
#   ./deploy.sh destroy  # Destroy all resources
#   ./deploy.sh help     # Show help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Record start time
START_TIME=$(date +%s)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

show_help() {
    echo ""
    echo "Multi-Cloud Deployment Script - Project Tracker"
    echo ""
    echo "Usage: $0 <provider> [command]"
    echo ""
    echo "Providers:"
    echo "  aws      Deploy to Amazon Web Services"
    echo "  azure   Deploy to Microsoft Azure"
    echo "  gcp     Deploy to Google Cloud Platform"
    echo "  all     Deploy to all enabled clouds"
    echo ""
    echo "Commands:"
    echo "  (none)   Deploy resources"
    echo "  plan     Show deployment plan"
    echo "  destroy  Delete all resources"
    echo "  output   Show deployment outputs"
    echo ""
    echo "Examples:"
    echo "  $0 aws        # Deploy to AWS"
    echo "  $0 azure      # Deploy to Azure"
    echo "  $0 gcp        # Deploy to GCP"
    echo "  $0 all plan   # Show plan for all clouds"
    echo "  $0 aws destroy # Delete AWS resources"
    echo ""
}

# -----------------------------------------------------------------------------
# Prerequisites Check
# -----------------------------------------------------------------------------

check_prerequisites() {
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        echo "Install from: https://www.terraform.io/downloads"
        exit 1
    fi

    # Check provider CLI based on cloud
    case "$1" in
        aws)
            if ! command -v aws &> /dev/null; then
                print_error "AWS CLI is not installed."
                exit 1
            fi
            print_success "AWS CLI found"
            ;;
        azure)
            if ! command -v az &> /dev/null; then
                print_error "Azure CLI is not installed."
                exit 1
            fi
            print_success "Azure CLI found"
            ;;
        gcp)
            if ! command -v gcloud &> /dev/null; then
                print_error "Google Cloud SDK is not installed."
                exit 1
            fi
            print_success "Google Cloud SDK found"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Terraform Init
# -----------------------------------------------------------------------------

terraform_init() {
    print_header "Initializing Terraform"
    cd "$TERRAFORM_DIR"
    terraform init
}

# -----------------------------------------------------------------------------
# Deploy to Cloud
# -----------------------------------------------------------------------------

deploy_to_cloud() {
    local cloud=$1
    local varfile="${cloud}.tfvars"

    print_header "Deploying to ${cloud^^}"

    # Check if varfile exists
    if [ ! -f "$TERRAFORM_DIR/${varfile}" ]; then
        print_error "Configuration file not found: ${varfile}"
        return 1
    fi

    # Initialize if needed
    if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
        terraform_init
    fi

    cd "$TERRAFORM_DIR"

    # Plan
    print_warning "Creating deployment plan..."
    terraform plan -var-file="${varfile}" -out=tfplan

    # Apply
    print_warning "Applying deployment..."
    terraform apply tfplan

    # Show outputs
    print_header "Deployment Outputs"
    terraform output
}

# -----------------------------------------------------------------------------
# Plan Cloud
# -----------------------------------------------------------------------------

plan_cloud() {
    local cloud=$1
    local varfile="${cloud}.tfvars"

    print_header "Planning ${cloud^^} Deployment"

    if [ ! -f "$TERRAFORM_DIR/${varfile}" ]; then
        print_error "Configuration file not found: ${varfile}"
        return 1
    fi

    if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
        terraform_init
    fi

    cd "$TERRAFORM_DIR"
    terraform plan -var-file="${varfile}"
}

# -----------------------------------------------------------------------------
# Destroy Cloud
# -----------------------------------------------------------------------------

destroy_cloud() {
    local cloud=$1
    local varfile="${cloud}.tfvars"

    print_header "Destroying ${cloud^^} Resources"

    if [ ! -f "$TERRAFORM_DIR/${varfile}" ]; then
        print_error "Configuration file not found: ${varfile}"
        return 1
    fi

    cd "$TERRAFORM_DIR"
    terraform destroy -var-file="${varfile}"
}

# -----------------------------------------------------------------------------
# Show Output
# -----------------------------------------------------------------------------

show_output() {
    local cloud=$1

    print_header "${cloud^^} Outputs"
    cd "$TERRAFORM_DIR"
    terraform output deployment_summary
}

# -----------------------------------------------------------------------------
# Calculate Time
# -----------------------------------------------------------------------------

print_deployment_time() {
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local MINUTES=$((ELAPSED / 60))
    local SECONDS=$((ELAPSED % 60))

    echo ""
    print_header "Deployment Complete!"
    echo ""
    echo -e "Total time: ${GREEN}${MINUTES}m ${SECONDS}s${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    local cloud=${1:-help}
    local command=${2:-deploy}

    # Handle help
    if [ "$cloud" = "help" ] || [ "$cloud" = "-h" ] || [ "$cloud" = "--help" ]; then
        show_help
        exit 0
    fi

    # Handle destroy all
    if [ "$cloud" = "destroy" ]; then
        print_warning "This will destroy resources in ALL clouds."
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        if [ "$confirm" = "yes" ]; then
            destroy_cloud aws || true
            destroy_cloud azure || true
            destroy_cloud gcp || true
        fi
        exit 0
    fi

    # Validate cloud
    case "$cloud" in
        aws|azure|gcp)
            ;;
        all)
            check_prerequisites aws
            check_prerequisites azure
            check_prerequisites gcp
            terraform_init
            ;;
        *)
            print_error "Unknown cloud provider: $cloud"
            echo "Valid options: aws, azure, gcp, all, destroy, help"
            exit 1
            ;;
    esac

    # Execute command
    case "$command" in
        plan)
            if [ "$cloud" = "all" ]; then
                plan_cloud aws
                plan_cloud azure
                plan_cloud gcp
            else
                check_prerequisites "$cloud"
                plan_cloud "$cloud"
            fi
            ;;
        destroy)
            if [ "$cloud" = "all" ]; then
                read -p "Destroy all clouds? Type 'yes': " confirm
                [ "$confirm" = "yes" ] && destroy_cloud aws && destroy_cloud azure && destroy_cloud gcp
            else
                destroy_cloud "$cloud"
            fi
            ;;
        output)
            show_output "$cloud"
            ;;
        deploy|"")
            if [ "$cloud" = "all" ]; then
                deploy_to_cloud aws
                deploy_to_cloud azure
                deploy_to_cloud gcp
            else
                check_prerequisites "$cloud"
                deploy_to_cloud "$cloud"
            fi
            print_deployment_time
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Valid commands: plan, deploy, destroy, output"
            exit 1
            ;;
    esac
}

# Run
main "$@"
