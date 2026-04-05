// =============================================================================
// GCP-Only Terraform Configuration - Project Tracker
// =============================================================================
// GCP-specific Terraform configuration for deploying the Project Tracker
// Flask application to Google Cloud Platform Compute Engine instances.
//
// This configuration deploys:
//   - Firewall Rules (SSH and HTTP)
//   - Static External IP
//   - Compute Engine Instance
//
// Usage:
//   terraform init
//   terraform plan -var-file=gcp.tfvars
//   terraform apply -var-file=gcp.tfvars
// =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

// Generates a unique ID for resource naming
resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

// Main GCP deployment module
module "gcp_deployment" {
  source = "./modules/gcp"

  // Resource naming
  prefix    = var.prefix
  region    = var.gcp_region
  random_id = random_id.main.hex

  // Instance settings
  machine_type = var.gcp_machine_type

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
    cloud       = "GCP"
    public_ip   = module.gcp_deployment.public_ip
    instance    = module.gcp_deployment.instance_name
    zone        = module.gcp_deployment.zone
    app_url     = module.gcp_deployment.app_url
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

variable "gcp_project_id" {
  description = "GCP Project ID (required - update in gcp.tfvars)"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "northamerica-northeast1"
}

variable "gcp_machine_type" {
  description = "GCP machine type (e.g., e2-standard-2)"
  type        = string
  default     = "e2-standard-2"
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
