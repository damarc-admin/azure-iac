// =============================================================================
// Multi-Cloud Terraform Configuration - Project Tracker
// =============================================================================
// Deploys the Project Tracker application to AWS, Azure, and GCP
// 
// Usage:
//   terraform init
//   terraform workspace new aws     # Create workspace for AWS
//   terraform workspace new azure  # Create workspace for Azure
//   terraform workspace new gcp    # Create workspace for GCP
//   terraform workspace select aws  # Select target cloud
//   terraform plan -var-file=aws.tfvars
//   terraform apply
// =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
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

// =============================================================================
// AWS Provider Configuration
// =============================================================================
// Uses default credentials from environment or ~/.aws/credentials
provider "aws" {
  region = var.aws_region

  # Optional: Use profile from AWS credentials file
  # profile = "default"

  alias = "aws"
}

// =============================================================================
// Azure Provider Configuration
// =============================================================================
provider "azurerm" {
  features {}

  alias = "azure"
}

// =============================================================================
// GCP Provider Configuration
// =============================================================================
// Uses Application Default Credentials (gcloud auth application-default login)
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region

  alias = "gcp"
}

// =============================================================================
// Random ID for Unique Naming
// =============================================================================
// Generates a random ID to ensure unique resource names across clouds
resource "random_id" "main" {
  byte_length = 4
  prefix      = "pt-"
}

// =============================================================================
// AWS Resources
// =============================================================================
// Deploys to Amazon Web Services
module "aws_deployment" {
  source = "./modules/aws"

  providers = {
    aws = aws.aws
  }

  count = var.enable_aws ? 1 : 0

  prefix        = var.prefix
  instance_type = var.aws_instance_type
  region        = var.aws_region
  app_port      = var.app_port
  ssh_cidr      = var.ssh_cidr
  app_cidr      = var.app_cidr
  random_id     = random_id.main.hex
}

// =============================================================================
// Azure Resources
// =============================================================================
// Deploys to Microsoft Azure
module "azure_deployment" {
  source = "./modules/azure"

  providers = {
    azurerm = azurerm.azure
  }

  count = var.enable_azure ? 1 : 0

  prefix      = var.prefix
  location    = var.azure_location
  vm_size     = var.azure_vm_size
  app_port    = var.app_port
  ssh_cidr    = var.ssh_cidr
  app_cidr    = var.app_cidr
  random_id   = random_id.main.hex
}

// =============================================================================
// GCP Resources
// =============================================================================
// Deploys to Google Cloud Platform
module "gcp_deployment" {
  source = "./modules/gcp"

  providers = {
    google = google.gcp
  }

  count = var.enable_gcp ? 1 : 0

  prefix      = var.prefix
  region      = var.gcp_region
  machine_type = var.gcp_machine_type
  app_port    = var.app_port
  ssh_cidr    = var.ssh_cidr
  app_cidr    = var.app_cidr
  random_id   = random_id.main.hex
}

// =============================================================================
// Deployment Summary
// =============================================================================
output "deployment_summary" {
  description = "Summary of deployments"

  value = {
    aws = var.enable_aws ? {
      enabled   = true
      public_ip = try(module.aws_deployment[0].public_ip, null)
      url       = try("http://${module.aws_deployment[0].public_ip}:${var.app_port}", null)
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }

    azure = var.enable_azure ? {
      enabled   = true
      public_ip = try(module.azure_deployment[0].public_ip, null)
      url       = try("http://${module.azure_deployment[0].public_ip}:${var.app_port}", null)
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }

    gcp = var.enable_gcp ? {
      enabled   = true
      public_ip = try(module.gcp_deployment[0].public_ip, null)
      url       = try("http://${module.gcp_deployment[0].public_ip}:${var.app_port}", null)
    } : {
      enabled   = false
      public_ip = null
      url       = null
    }
  }
}
