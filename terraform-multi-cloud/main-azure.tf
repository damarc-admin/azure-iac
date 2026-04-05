// =============================================================================
// Azure-Only Terraform Configuration - Project Tracker
// =============================================================================
// Azure-specific Terraform configuration for deploying the Project Tracker
// Flask application to Microsoft Azure Virtual Machines.
//
// This configuration deploys:
//   - Resource Group
//   - Virtual Network with Subnet
//   - Network Security Group
//   - Public IP Address
//   - Network Interface
//   - Linux Virtual Machine
//   - Custom Script Extension for app deployment
//
// Usage:
//   terraform init
//   terraform plan -var-file=azure.tfvars
//   terraform apply -var-file=azure.tfvars
// =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// Generates a unique ID for resource naming to avoid conflicts
resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

// Main Azure deployment module
module "azure_deployment" {
  source = "./modules/azure"

  // Resource naming
  prefix    = var.prefix
  random_id = random_id.main.hex

  // Azure-specific settings
  location  = var.azure_location
  vm_size   = var.azure_vm_size

  // Application settings
  app_port = var.app_port

  // Security settings
  ssh_cidr = var.ssh_cidr
  app_cidr = var.app_cidr

  // Deployment metadata (passed from deploy script)
  deployed_by   = var.deployed_by
  deployed_date = var.deployed_date
}

// =============================================================================
// Outputs
// =============================================================================

output "deployment_summary" {
  value = {
    cloud          = "Azure"
    public_ip      = module.azure_deployment.public_ip
    vm_name        = module.azure_deployment.vm_name
    resource_group = module.azure_deployment.resource_group
    app_url        = module.azure_deployment.app_url
  }
}

// =============================================================================
// Variables
// =============================================================================

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "project-tracker"
}

variable "azure_location" {
  description = "Azure region for deployment"
  type        = string
  default     = "canadacentral"
}

variable "azure_vm_size" {
  description = "Azure VM size (e.g., Standard_D2s_v3)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "app_port" {
  description = "Application port (Flask default is 5000)"
  type        = string
  default     = "5000"
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access (0.0.0.0/0 for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_cidr" {
  description = "CIDR block for application access (0.0.0.0/0 for anywhere)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "deployed_by" {
  description = "Username of the person deploying (set by deploy script)"
  type        = string
  default     = "unknown"
}

variable "deployed_date" {
  description = "Date of deployment in YYYY-MM-DD format (set by deploy script)"
  type        = string
  default     = "unknown"
}
