#!/bin/bash

# =============================================================================
# Multi-Cloud Deployment Script - Project Tracker
# =============================================================================
# Deploys to the specified cloud provider using cloud-specific Terraform config
#
# Usage:
#   ./deploy.sh aws       # Deploy to AWS
#   ./deploy.sh azure    # Deploy to Azure
#   ./deploy.sh gcp      # Deploy to GCP
#   ./deploy.sh help     # Show help
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

START_TIME=$(date +%s)

# Helper Functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

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
    echo ""
    echo "Commands:"
    echo "  (none)   Deploy resources"
    echo "  plan     Show deployment plan"
    echo "  destroy  Delete all resources"
    echo "  output   Show deployment outputs"
    echo ""
    echo "Examples:"
    echo "  $0 aws        # Deploy to AWS"
    echo "  $0 azure     # Deploy to Azure"
    echo "  $0 gcp       # Deploy to GCP"
    echo "  $0 aws plan  # Show AWS plan"
    echo "  $0 aws destroy # Delete AWS resources"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi

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

# Terraform operations for specific cloud
run_terraform() {
    local cloud=$1
    local command=$2
    local config_file="main-${cloud}.tf"
    local varfile="${cloud}.tfvars"

    print_header "${cloud^^} - ${command}"

    if [ ! -f "$TERRAFORM_DIR/${config_file}" ]; then
        print_error "Config file not found: ${config_file}"
        return 1
    fi

    if [ ! -f "$TERRAFORM_DIR/${varfile}" ]; then
        print_error "Variable file not found: ${varfile}"
        return 1
    fi

    cd "$TERRAFORM_DIR"

    # Remove other config files to avoid conflicts
    for f in main.tf main-aws.tf main-azure.tf main-gcp.tf; do
        if [ "$f" != "$config_file" ]; then
            [ -f "$f" ] && rm -f "$f"
        fi
    done

    # Initialize with specific config
    terraform init -upgrade

    case "$command" in
        plan)
            terraform plan -var-file="${varfile}"
            ;;
        apply)
            terraform plan -var-file="${varfile}" -out=tfplan
            terraform apply tfplan
            terraform output
            ;;
        destroy)
            read -p "Destroy ${cloud^^} resources? Type 'yes': " confirm
            [ "$confirm" = "yes" ] && terraform destroy -var-file="${varfile}"
            ;;
        output)
            terraform output
            ;;
    esac
}

# Calculate time
print_deployment_time() {
    local END_TIME=$(date +%s)
    local ELAPSED=$((END_TIME - START_TIME))
    local MINUTES=$((ELAPSED / 60))
    local SECONDS=$((ELAPSED % 60))
    echo ""
    print_header "Deployment Complete!"
    echo -e "Total time: ${GREEN}${MINUTES}m ${SECONDS}s${NC}"
    echo ""
}

# Main
main() {
    local cloud=${1:-help}
    local command=${2:-apply}

    if [ "$cloud" = "help" ] || [ "$cloud" = "-h" ]; then
        show_help
        exit 0
    fi

    case "$cloud" in
        aws|azure|gcp)
            check_prerequisites "$cloud"
            run_terraform "$cloud" "$command"
            [ "$command" = "apply" ] && print_deployment_time
            ;;
        *)
            print_error "Unknown cloud: $cloud"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
